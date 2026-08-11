#!/usr/bin/env bash
# One-screen summary of local compute: CPU, memory, storage, GPU (NVIDIA).
#
# Safe to run inside a drydock container as well as on the host. The hardware
# rows read the same either way — the container shares the host's kernel,
# /dev/dri and /dev/nvidia* — so the only row that actually changes is the
# toolchain one, which is the reason to run it inside.
set -uo pipefail

# One lscpu call, parsed repeatedly. LC_ALL=C so the keys below are the
# English ones no matter what locale the caller runs in.
cpuinfo=$(LC_ALL=C lscpu 2>/dev/null)
lsc() { awk -F: -v k="$1" '$1==k{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}' <<<"$cpuinfo"; }
row() { printf '%-8s %s\n' "$1" "$2"; }

# --- context ---
# Marker files cover Docker and Podman. Under containerd or Kubernetes neither
# exists and cgroup v2 reports a bare "0::/" where the host shows a real path
# (0::/init.scope, 0::/user.slice/...), so test for that too.
in_container() {
  { [ -f /.dockerenv ] || [ -f /run/.containerenv ]; } && return 0
  grep -qE '(docker|containerd|libpod|kubepods)' /proc/1/cgroup 2>/dev/null && return 0
  [ "$(cat /proc/1/cgroup 2>/dev/null)" = "0::/" ]
}
if in_container; then
  row context "container — distro below is the image; cpu/memory/gpu are the host's"
fi

# --- host ---
distro=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
row host "$(hostname) — ${distro:-unknown} — $(uname -sr)"

# --- cpu ---
# All three counts come from lscpu: nproc would report the process's affinity
# or cgroup limit while cores/sockets come from hardware topology, which in a
# constrained container prints nonsense like 32C/8T.
model=$(lsc 'Model name')
cores=$(lsc 'Core(s) per socket'); sockets=$(lsc 'Socket(s)'); threads=$(lsc 'CPU(s)')
ghz=$(lsc 'CPU max MHz' | awk 'NF{printf "%.2f", $1/1000}')
l3=$(lsc 'L3 cache' | sed 's/ (.*//')

# Highest vector ISA present, from a single read of the first flags line. Only
# matters for diagnosing an `Illegal instruction` from a binary built for a
# wider ISA than this CPU has.
flags=$(awk -F': ' '/^flags[ \t]*:/{print $2; exit}' /proc/cpuinfo 2>/dev/null)
for f in amx_tile avx512f avx2 avx; do
  case " $flags " in *" $f "*) simd=$f; break ;; esac
done
row cpu "$model — $(( ${cores:-0} * ${sockets:-0} ))C/${threads:-?}T @ ${ghz:-?} GHz, L3 ${l3:-?}, ${simd:-no avx}"

# --- memory / storage ---
row memory "$(LC_ALL=C free -h | awk '/^Mem:/{print $2" total, "$7" available"}')"
# $HOME, not /: inside the container / is the image's overlay, while $HOME is
# the bind mount where the work actually lives. On this host they are separate
# partitions too, so / would have reported the wrong disk either way.
row storage "$(df -h "$HOME" | awk -v h="$HOME" 'NR==2{print h" "$2" total, "$4" free ("$5" used)"}')"

# --- gpu ---
# Capture first: nvidia-smi can be on PATH and still fail (no driver, no
# device, an option this driver version does not know), and an empty or failed
# query should fall through to the lspci path rather than print a blank row.
if gpus=$(nvidia-smi --query-gpu=index,name,memory.total,memory.used,compute_cap,driver_version \
                     --format=csv,noheader,nounits 2>/dev/null) && [ -n "$gpus" ]; then
  while IFS=, read -r idx name total used cc drv; do
    row "gpu$idx" "$name — $total MiB ($used MiB used), cc $cc, driver $drv"
  done < <(sed 's/, /,/g' <<<"$gpus")
else
  gpu=""
  if command -v lspci >/dev/null 2>&1; then
    # No -m1/head: an early exit would SIGPIPE lspci, and under pipefail that
    # turns a successful lookup into a failure. Match once inside awk instead.
    gpu=$(lspci 2>/dev/null | awk 'tolower($0) ~ /vga|3d|display/ && !seen {seen=1; sub(/^[^:]*:[^:]*:[ ]*/,""); print}' | xargs)
  fi
  # The drydock image does not install pciutils, so on the container path fall
  # back to the mapped render nodes rather than claiming there is no GPU.
  if [ -z "$gpu" ] && compgen -G '/dev/dri/render*' >/dev/null; then
    gpu="$(echo /dev/dri/*) mapped in (install pciutils for the model name)"
  fi
  row gpu "${gpu:-none}"
fi

# --- toolchain: the row that differs between host and container ---
cuda=$(nvcc --version 2>/dev/null | sed -n 's/.*release \([0-9.]*\).*/nvcc \1/p')
torch=$(python3 -c 'import torch;print(f"torch {torch.__version__} (cuda {torch.version.cuda}, avail {torch.cuda.is_available()})")' 2>/dev/null)
row cuda "${cuda:-nvcc not found}; ${torch:-torch not found}"
