#!/usr/bin/env bash

if [[ "$(uname)" == "Darwin" ]]; then
  SED_INPLACE=(-i '')
else
  SED_INPLACE=(-i)
fi

set -e

PACKAGE=$1
DATAMODEL=$2
APPNAME=$3

if [[ -z "$PACKAGE" ]]; then
    read -p "Enter new package name (e.g. com.example.app): " PACKAGE
fi
if [[ -z "$PACKAGE" ]]; then
    echo "Package name is required. Exiting." >&2
    exit 2
fi

if [[ -z "$DATAMODEL" ]]; then
    read -p "Enter new data model name (e.g. Item): " DATAMODEL
fi
if [[ -z "$DATAMODEL" ]]; then
    echo "Data model name is required. Exiting." >&2
    exit 2
fi

if [[ -z "$APPNAME" ]]; then
    read -p "Enter application name (Optional, default: MyApplication): " APPNAME
fi
if [[ -z "$APPNAME" ]]; then
    APPNAME="MyApplication"
fi
SUBDIR=${PACKAGE//.//}

DATAMODEL_UPPER="$(echo "$DATAMODEL" | awk '{print toupper(substr($0,1,1)) substr($0,2)}')"
DATAMODEL_LOWER="$(echo "$DATAMODEL" | awk '{print tolower(substr($0,1,1)) substr($0,2)}')"
DATAMODEL_ALL_LOWER="$(echo "$DATAMODEL" | tr '[:upper:]' '[:lower:]')"

for n in $(find . -type d \( -path '*/src/androidTest' -or -path '*/src/main' -or -path '*/src/test' \) )
do
  moved=0
  for SRCTYPE in kotlin java; do
    SRC="$n/$SRCTYPE/android/template"
    if [[ ! -d "$SRC" ]]; then
      continue
    fi
    echo "Creating $n/$SRCTYPE/$SUBDIR"
    mkdir -p "$n/$SRCTYPE/$SUBDIR"
    echo "Moving files to $n/$SRCTYPE/$SUBDIR"
    cp -r "$SRC/." "$n/$SRCTYPE/$SUBDIR/"
    echo "Removing old $n/$SRCTYPE/android"
    rm -rf "$n/$SRCTYPE/android"
    find "$n/$SRCTYPE" -type d -empty -delete 2>/dev/null || true
    moved=1
  done
  if [[ $moved -eq 0 ]]; then
    echo "Skipping $n (no android/template source found)"
  fi
done

echo "Renaming packages to $PACKAGE"
find ./ -type f -name "*.kt" -exec sed "${SED_INPLACE[@]}" "s/package android.template/package $PACKAGE/g" {} \;
find ./ -type f -name "*.kt" -exec sed "${SED_INPLACE[@]}" "s/import android.template/import $PACKAGE/g" {} \;

# Rename .kts files (modules AND build-logic)
find ./ -type f -name "*.kts" -exec sed "${SED_INPLACE[@]}" "s/android.template/$PACKAGE/g" {} \;

# Rename build-logic plugin group (e.g. android.template.buildlogic -> com.example.app.buildlogic)
# Already covered by the *.kts rule above (group = "android.template.buildlogic")

# Rename build-logic plugin IDs: template.android.* -> <last segment of package>.android.*
# e.g. com.example.app -> app; plugin id prefix changes from "template" to that last segment
PKG_LAST="$(echo "$PACKAGE" | awk -F'.' '{print $NF}')"
find ./build-logic -type f -name "*.kts" -exec sed "${SED_INPLACE[@]}" "s/template\.android/$PKG_LAST.android/g" {} \;
find ./build-logic -type f -name "*.kts" -exec sed "${SED_INPLACE[@]}" "s/template\.hilt/$PKG_LAST.hilt/g" {} \;
# Convention plugin sources also embed plugin IDs as strings (apply(plugin = "template.android.library.compose"))
find ./build-logic -type f -name "*.kt" -exec sed "${SED_INPLACE[@]}" "s/template\.android/$PKG_LAST.android/g" {} \;
find ./build-logic -type f -name "*.kt" -exec sed "${SED_INPLACE[@]}" "s/template\.hilt/$PKG_LAST.hilt/g" {} \;
# Rename plugin references in all module build.gradle.kts
find ./ -path ./build-logic -prune -o -type f -name "*.kts" -exec sed "${SED_INPLACE[@]}" "s/template\.android/$PKG_LAST.android/g" {} \;
find ./ -path ./build-logic -prune -o -type f -name "*.kts" -exec sed "${SED_INPLACE[@]}" "s/template\.hilt/$PKG_LAST.hilt/g" {} \;
# Also fix plugin alias entries in libs.versions.toml (both the id values and the dash-form keys)
find ./gradle -type f -name "*.toml" -exec sed "${SED_INPLACE[@]}" "s/template\.android/$PKG_LAST.android/g" {} \;
find ./gradle -type f -name "*.toml" -exec sed "${SED_INPLACE[@]}" "s/template\.hilt/$PKG_LAST.hilt/g" {} \;
find ./gradle -type f -name "*.toml" -exec sed "${SED_INPLACE[@]}" "s/^template-android/$PKG_LAST-android/g" {} \;
find ./gradle -type f -name "*.toml" -exec sed "${SED_INPLACE[@]}" "s/^template-hilt/$PKG_LAST-hilt/g" {} \;

echo "Renaming model to $DATAMODEL"
find ./ -type f -name "*.kt" -exec sed "${SED_INPLACE[@]}" "s/Post/$DATAMODEL_UPPER/g" {} \;
find ./ -type f -name "*.kt" -exec sed "${SED_INPLACE[@]}" "s/post/$DATAMODEL_LOWER/g" {} \;
find ./ -type f -name "*.kt*" -exec sed "${SED_INPLACE[@]}" "s/post/$DATAMODEL_ALL_LOWER/g" {} \;

echo "Cleaning up"
find . -name "*.bak" -type f -delete

echo "Renaming files to $DATAMODEL"
if [[ "$DATAMODEL_UPPER" != "Post" ]]; then
  # -depth: rename files before their parent dirs are renamed
  find ./ -depth -type f -name "*Post*.kt" | while IFS= read -r f; do
    parent="$(dirname "$f")"
    base="$(basename "$f")"
    mv "$f" "$parent/${base//Post/$DATAMODEL_UPPER}"
  done
fi

if [[ "$DATAMODEL_ALL_LOWER" != "post" ]]; then
  echo "Renaming directories to $DATAMODEL"
  # -depth processes leaves first so nested `post` dirs rename before their parents
  find ./ -depth -type d -name "post" | while IFS= read -r d; do
    mv "$d" "${d%/post}/$DATAMODEL_ALL_LOWER"
  done
fi

if [[ $APPNAME != MyApplication ]]
then
    echo "Renaming app to $APPNAME"
    find ./ -type f \( -name "*.kt" -or -name "*.kts" -or -name "*.xml" -or -path "*/src/main/AndroidManifest.xml" \) -exec sed "${SED_INPLACE[@]}" "s/MyApplication/$APPNAME/g" {} \;
    find ./ -name "MyApplication.kt" | sed "p;s/MyApplication/$APPNAME/" | tr '\n' '\0' | xargs -0 -n 2 mv
    find . -name "*.bak" -type f -delete
fi

echo "Removing additional files"
rm -rf CONTRIBUTING.md LICENSE README.md customizer.sh trim.sh
echo "Done!"