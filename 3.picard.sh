#!/bin/bash

# 设置Picard软件的路径
picard_jar_path=~/anaconda2/bin/picard

# 设置输出目录
output_dir="/public1/guop/jpq/workspace/bwa_map/"

# 定义参考基因组文件
reference_genome="/public1/guop/jpq/0.genome/LYG.hic.fasta"

# 设置Picard输出目录，包含metrics文件夹
picard_dir="/public1/guop/jpq/workspace/bwa_map/picard_metrics"

# 创建输出目录（如果不存在）
mkdir -p "$output_dir/sorted_bam" "$output_dir/markdup" "$output_dir/tmp" "$picard_dir" "$output_dir/unmapped_bam"

# 设置日志文件
log_file="$output_dir/picard_markduplicates_processing.log"

# 记录脚本开始时间
echo "Script started at $(date)" >> "$log_file"

# 定义处理BAM文件的函数
process_picard() {
    sorted_bam_path=$1
    base_name=$(basename "$sorted_bam_path" ".sorted.bam")  # 从BAM文件名提取基本文件名
    outdir=$(dirname "$sorted_bam_path")  # 获取sorted_bam_path的目录路径
    
    # Picard MarkDuplicates去重
    echo "Marking duplicates for $base_name at $(date)" >> "$log_file"
    $picard_jar_path MarkDuplicates \
        -I "$sorted_bam_path" \
        -O "$output_dir/markdup/${base_name}.markdup.bam" \
        -M "/public1/guop/jpq/workspace/bwa_map/picard_metrics/${base_name}.metrics.txt" \
        --MAX_FILE_HANDLES_FOR_READ_ENDS_MAP 1000 \
        --REMOVE_DUPLICATES false \
        --ASSUME_SORTED true \
        --VALIDATION_STRINGENCY LENIENT \
        --TMP_DIR "$output_dir/tmp" || { echo "MarkDuplicates failed for $base_name"; exit 1; }
    echo "Marking duplicates completed for $base_name at $(date)" >> "$log_file"
    
    # samtools index对去重后的BAM文件建立索引
    echo "Indexing marked duplicates BAM for $base_name at $(date)" >> "$log_file"
    samtools index -@ 16 "$output_dir/markdup/${base_name}.markdup.bam" || { echo "Indexing failed for $base_name"; exit 1; }
    echo "Indexing marked duplicates BAM completed for $base_name at $(date)" >> "$log_file"
     # 提取未映射的reads
    samtools view -b -f 4 "$output_dir/markdup/${base_name}.markdup.bam" > "$output_dir/unmapped_bam/${base_name}.unmapped.bam" || { echo "Failed to extract unmapped reads for $base_name" >> "$log_file"; exit 1; }
}

export -f process_picard
export picard_jar_path
export output_dir
export reference_genome
export log_file

# 使用find命令和parallel并行处理sorted_bam目录中的所有BAM文件
find "$output_dir/sorted_bam" -name '*.sorted.bam' | sort | parallel -j 15 process_picard {}

# 记录脚本完成时间
echo "Script completed at $(date)" >> "$log_file"
