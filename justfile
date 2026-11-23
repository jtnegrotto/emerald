default: generate-git-patch generate-rom-patch

verify-base:
  echo "f3ae088181bf583e55daf962a92bb46f4f1d07b7  base.gba" | sha1sum -c -

generate-git-patch:
  git -C ../pokeemerald diff --patch vanilla > pokeemerald.patch

generate-rom-patch: verify-base
  make -C ../pokeemerald
  flips --create --bps base.gba ../pokeemerald/pokeemerald.gba emerald-patched.bps
