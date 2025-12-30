#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <modelscope_model_id> [ollama_tag]"
  echo "Example: $0 zhaohb/DeepSeek-R1-Distill-Qwen-1.5B-int4-ov-npu v1"
  exit 1
fi

MODEL_ID="$1"
TAG="${2:-v1}"

MODELS_DIR="/root/.ollama/models-src"
MODEL_NAME="${MODEL_ID##*/}"
MODEL_DIR="${MODELS_DIR}/${MODEL_NAME}"
TAR_NAME="${MODEL_NAME}.tar.gz"
TAR_PATH="${MODELS_DIR}/${TAR_NAME}"

if ! command -v ollama >/dev/null 2>&1; then
  echo "Error: ollama not found in PATH."
  exit 1
fi

if ! command -v modelscope >/dev/null 2>&1; then
  if ! command -v pip >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "Error: python3 and pip not found. Install python3 and pip first."
    exit 1
  fi

  if ! command -v pip >/dev/null 2>&1; then
    if command -v apt-get >/dev/null 2>&1; then
      apt-get update
      apt-get install -y python3-pip
    else
      echo "Error: pip not found and no supported package manager available."
      exit 1
    fi
  fi

  if command -v pip >/dev/null 2>&1; then
    pip install modelscope
  else
    python3 -m pip install modelscope
  fi
fi

mkdir -p "${MODELS_DIR}"

if [ -d "${MODEL_DIR}" ] && [ "$(ls -A "${MODEL_DIR}")" ]; then
  echo "Model directory exists, skipping download: ${MODEL_DIR}"
else
  modelscope download --model "${MODEL_ID}" --local_dir "${MODEL_DIR}"
fi

cd "${MODELS_DIR}"
if [ -f "${TAR_PATH}" ]; then
  echo "Tarball exists, skipping archive: ${TAR_PATH}"
else
  tar -zcvf "${TAR_NAME}" "${MODEL_NAME}"
fi

MODELFILE_PATH="${MODELS_DIR}/${MODEL_NAME}.Modelfile"
cat > "${MODELFILE_PATH}" <<EOF
FROM ${TAR_PATH}
ModelType "OpenVINO"
InferDevice "NPU"
EOF

GENAI_SETUP="/home/ollama_ov_server/openvino_genai_ubuntu24_2025.4.1.0_x86_64/setupvars.sh"
if [ -f "${GENAI_SETUP}" ]; then
  # shellcheck disable=SC1090
  source "${GENAI_SETUP}"
fi

if command -v ollama >/dev/null 2>&1; then
  if ollama list 2>/dev/null | awk '{print $1}' | grep -x "${MODEL_NAME}:${TAG}" >/dev/null 2>&1; then
    echo "Ollama model already exists, skipping create: ${MODEL_NAME}:${TAG}"
    exit 0
  fi
fi

ollama create "${MODEL_NAME}:${TAG}" -f "${MODELFILE_PATH}"

echo "Created ollama model: ${MODEL_NAME}:${TAG}"
