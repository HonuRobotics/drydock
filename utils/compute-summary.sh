#!/usr/bin/env bash
# One-screen summary of local compute: CPU, memory, storage, GPU (NVIDIA).
#
# Safe to run inside a drydock container as well as on the host. The hardware
# rows read the same either way — the container shares the host's kernel,
# /dev/dri and /dev/nvidia* — so the only row that actually changes is the
# toolchain one, which is the reason to run it inside.
set -uo pipefail

lsc() { lscpu | awk -F: -v k="$1" '$1==k{gsub(/^[ \t]+|[ \t]+$/,"",$2); print $2; exit}'; }
row() { printf '%-8s %s\n' "$1" "$2"; }

# --- context ---
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || grep -qE '(docker|containerd)' /proc/1/cgroup 2>/dev/null; then
  row context "container — distro below is the image; cpu/memory/gpu are the host's"
fi

# --- host ---
distro=$(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME")
row host "$(hostname) — ${distro:-unknown} — $(uname -sr)"

# --- cpu ---
model=$(lsc 'Model name')
cores=$(lsc 'Core(s) per socket'); sockets=$(lsc 'Socket(s)'); threads=$(nproc)
ghz=$(lsc 'CPU max MHz' | awk 'NF{printf "%.2f", $1/1000}')
l3=$(lsc 'L3 cache' | sed 's/ (.*//')

# Highest vector ISA present. Only matters for diagnosing an `Illegal
# instruction` from a binary built for a wider ISA than this CPU has.
for f in amx_tile avx512f avx2 avx; do
  grep -qw "$f" /proc/cpuinfo && { simd=$f; break; }
done
row cpu "$model — $((cores * sockets))C/${threads}T @ ${ghz:-?} GHz, L3 ${l3:-?}, ${simd:-no avx}"

# --- memory / storage ---
row memory "$(free -h | awk '/^Mem:/{print $2" total, "$7" available"}')"
# $HOME, not /: inside the container / is the image's overlay, while $HOME is
# the bind mount where the work actually lives. On this host they are separate
# partitions too, so / would have reported the wrong disk either way.
row storage "$(df -h "$HOME" | awk -v h="$HOME" 'NR==2{print h" "$2" total, "$4" free ("$5" used)"}')"

# --- gpu ---
if command -v nvidia-smi >/dev/null 2>&1; then
  while IFS=, read -r idx name total used cc drv; do
    for v in name total used cc drv; do printf -v "$v" '%s' "${!v# }"; done
    row "gpu$idx" "$name — $total MiB ($used MiB used), cc $cc, driver $drv"
  done < <(nvidia-smi --query-gpu=index,name,memory.total,memory.used,compute_cap,driver_version \
                     --format=csv,noheader,nounits)
else
  row gpu "$(lspci 2>/dev/null | grep -iEm1 'vga|3d|display' | cut -d: -f3- | xargs || echo none)"
fi

# --- toolchain: the row that differs between host and container ---
cuda=$(nvcc --version 2>/dev/null | sed -n 's/.*release \([0-9.]*\).*/nvcc \1/p')
torch=$(python3 -c 'import torch;print(f"torch {torch.__version__} (cuda {torch.version.cuda}, avail {torch.cuda.is_available()})")' 2>/dev/null)
row cuda "${cuda:-nvcc not found}; ${torch:-torch not found}"
