#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=camera
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        system/lib64/libgui-xiaomi.so)
            [ "$2" = "" ] && return 0
            patchelf --set-soname libgui-xiaomi.so "${2}"
            ;;
        system/lib64/libcamera_algoup_jni.xiaomi.so|system/lib64/libcamera_mianode_jni.xiaomi.so)
            [ "$2" = "" ] && return 0
            patchelf --replace-needed libgui.so libgui-xiaomi.so "${2}"
            ;;
        system/priv-app/MiuiCamera/MiuiCamera.apk)
            [ "$2" = "" ] && return 0
            tmp_dir="${EXTRACT_TMP_DIR}/MiuiCamera"
            $APKTOOL d -q "$2" -o "$tmp_dir" -f
            echo "    - Patching apk..."
            # Use Google photos instead of MIUI gallery
            grep -rl "com.miui.gallery" "$tmp_dir" | xargs sed -i 's|"com.miui.gallery"|"com.google.android.apps.photos"|g'
            # Use the correct launcher icon
            sed -i "s/ic_launcher_camera_cv/ic_launcher_camera/" "$tmp_dir/AndroidManifest.xml"
            echo "    - Rebuilding apk..."
            $APKTOOL b -q "$tmp_dir" -o "$2"
            rm -rf "$tmp_dir"
            split --bytes=20M -d "$2" "$2".part
            ;;
       *)
            return 1
            ;;
    esac

     return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
