#!/usr/bin/env bash
# download_sra.sh
# Usage: ./download_sra.sh SRR_LIST_FILE OUTPUT_DIR THREADS
# Example: ./download_sra.sh SRR_Acc_List.txt ./raw_data 8

set -euo pipefail

SRR_LIST_FILE=${1:? "Please provide a file containing SRA accession IDs (one per line)"}
OUT_DIR=${2:-"./raw_data"}
THREADS=${3:-4}

mkdir -p "${OUT_DIR}"

FAILED_IDS=()

while IFS= read -r SRR_ID; do
  # Skip empty lines or comments
  [[ -z "$SRR_ID" || "$SRR_ID" =~ ^# ]] && continue

  echo "=== Processing ${SRR_ID} ==="

  {
    echo "=== Step 1: Prefetch ${SRR_ID} into ${OUT_DIR} ==="
    prefetch -O "${OUT_DIR}" "${SRR_ID}"

    SRA_PATH="${OUT_DIR}/${SRR_ID}.sra"

    if [ ! -f "${SRA_PATH}" ]; then
      echo "Error: Prefetch did not produce ${SRA_PATH}"
      FAILED_IDS+=("${SRR_ID}")
      continue
    fi

    echo "=== Step 2: Convert ${SRR_ID} to FASTQ with fasterq-dump ==="
    if ! fasterq-dump "${SRA_PATH}" --split-files -O "${OUT_DIR}" -e "${THREADS}"; then
      echo "Error: fasterq-dump failed for ${SRR_ID}. Cleaning up partial FASTQ files..."
      rm -f "${OUT_DIR}/${SRR_ID}"*.fastq
      FAILED_IDS+=("${SRR_ID}")
      continue
    fi

    echo "=== Done! FASTQ files for ${SRR_ID} are in ${OUT_DIR} ==="
  } || {
    echo "Unexpected error while processing ${SRR_ID}"
    FAILED_IDS+=("${SRR_ID}")
    continue
  }

done < "${SRR_LIST_FILE}"

echo "=== All SRR IDs processed. ==="
if [ ${#FAILED_IDS[@]} -gt 0 ]; then
  echo "The following IDs failed:"
  printf '%s\n' "${FAILED_IDS[@]}"
else
  echo "No failures — all IDs processed successfully!"
fi
