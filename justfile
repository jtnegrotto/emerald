set unstable
set lists

pokeemerald-base-commit := "8cf518839e529eeb2477905ede1df7213ac134b8"
agbcc-commit := "da598c1d918402c42c0c0d7128ba14567f3175e9"
base-rom-sha1 := "f3ae088181bf583e55daf962a92bb46f4f1d07b7"

# Not included here: autorun
features := [
  "scrollable-options",
  "indoor-running",
  "b-highlights-run",
  "default-set",
  "instant-text",
  "day-night-system",
  "faster-battles",
  "no-disappearing-berry-trees",
]

default: build-all

alias b := build-all
alias build := build-all
build-all: build-base-rom build-patched-rom build-rom-patch

clean:
  rm -f base.gba

pokeemerald-clone:
  test -d pokeemerald || git clone https://github.com/pret/pokeemerald pokeemerald

agbcc-clone:
  test -d agbcc || git clone https://github.com/pret/agbcc agbcc

pokeemerald-install-agbcc: agbcc-clone pokeemerald-clone
  #!/bin/bash
  set -euo pipefail
  test -d pokeemerald/tools/agbcc && exit 0
  cd agbcc
  git checkout --detach {{ agbcc-commit }}
  ./build.sh
  ./install.sh ../pokeemerald

pokeemerald-init: pokeemerald-install-agbcc

build-base-rom: pokeemerald-init
  #!/bin/bash
  set -euo pipefail
  test -f base.gba && exit 0
  git -C pokeemerald checkout --detach {{ pokeemerald-base-commit }}
  make -C pokeemerald -j "$(nproc)"
  cp pokeemerald/pokeemerald.gba base.gba
  echo "Verifying base ROM checksum..."
  echo "{{ base-rom-sha1 }}  base.gba" | sha1sum -c -

create-branch FEATURE:
  git -C pokeemerald switch -c "custom/{{ FEATURE }}" {{ pokeemerald-base-commit }}

checkout FEATURE:
  git -C pokeemerald checkout "custom/{{ FEATURE }}"

checkout-base:
  git -C pokeemerald checkout --detach {{ pokeemerald-base-commit }}

make:
  make -C pokeemerald

gen-git-patch FEATURE:
  #!/bin/bash
  set -euo pipefail
  mkdir -p patches
  rm -f "patches/{{ FEATURE }}.patch"
  if [ -f "headers/{{ FEATURE }}.txt" ]; then
    cp "headers/{{ FEATURE }}.txt" "patches/{{ FEATURE }}.patch"
    echo >> "patches/{{ FEATURE }}.patch"
  fi
  git -C pokeemerald diff --patch \
    {{ pokeemerald-base-commit }} "custom/{{ FEATURE }}" \
    >> "patches/{{ FEATURE }}.patch"
  echo "Created patches/{{ FEATURE }}.patch"

# Handle patches that depend on non-base branches
gen-special-git-patches:
  set -euo pipefail
  mkdir -p patches
  cp headers/autorun.txt patches/autorun.patch
  echo >> patches/autorun.patch
  git -C pokeemerald diff --patch \
    custom/scrollable-options custom/autorun \
    >> patches/autorun.patch

gen-git-patches: *(gen-git-patch *features) (gen-git-patch "all") gen-special-git-patches

merge-into-all FEATURE:
  git -C pokeemerald checkout "custom/all"
  git -C pokeemerald merge "custom/{{ FEATURE }}"

merge-all: *(merge-into-all *features) (merge-into-all "autorun")

build-patched-rom:
  git -C pokeemerald checkout -b "custom/build" "custom/all"
  make -C pokeemerald
  cp -f pokeemerald/pokeemerald.gba patched.gba
  git -C pokeemerald checkout --detach "{{ pokeemerald-base-commit }}"
  git -C pokeemerald branch -D "custom/build"

build-rom-patch:
  flips --create --bps base.gba patched.gba patch.bps
