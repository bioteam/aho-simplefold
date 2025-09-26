#!/usr/bin/env nextflow

/* 
 * © 2025 BioTeam, LLC All rights reserved.
 * SimpleFold Protein Structure Prediction Workflow
 * Runs on AWS HealthOmics
 */

// Enable DSL2
nextflow.enable.dsl=2

// Define the SimpleFold process
process SimpleFoldInference {
    tag "$fasta.baseName"
    publishDir "/mnt/workflow/pubdir"
    label 'simplefold_container'

    // Resource requirements
    cpus 4
    memory '32 GB'
    accelerator 1, type: 'nvidia-l40s'
    
    input:
    path fasta
    
    output:
    path "*.cif", emit: structures
    path "*.json", emit: records, optional: true
    path "*.npz", emit: embeddings, optional: true
    
    script:
    def plddt_flag = params.enable_plddt ? '--plddt' : ''
    """
    set -euxo pipefail

    # Create output directory
    mkdir -p output/cache

    # Copy cached files to expected location in output directory
    cp /app/ml-simplefold/cache/boltz1_conf.ckpt output/cache/boltz1_conf.ckpt
    cp /app/ml-simplefold/cache/ccd.pkl output/cache/ccd.pkl

    # Get ABS path of output directory
    output_dir=\$(realpath output)
    input_fasta=\$(realpath ${fasta})

    pushd /app/ml-simplefold
    
    # Run SimpleFold prediction
    simplefold \
        --simplefold_model ${params.simplefold_model} \
        --num_steps ${params.num_steps} \
        --tau ${params.tau} \
        --nsample_per_protein ${params.nsample_per_protein} \
        ${plddt_flag} \
        --fasta_path \${input_fasta} \
        --backend torch \
        --output_dir \${output_dir}

    popd
    
    # Move outputs to current directory
    find \${output_dir} -name "*.cif" -exec mv {} . \\;
    find \${output_dir} -name "*.json" -exec mv {} . \\;
    find \${output_dir} -name "*.npz" -exec mv {} . \\;
    """
}

// Main workflow
workflow {
    input_dir = params.input_dir

    // Add forward slash to input_dir if missing
    if (!input_dir.endsWith('/')) {
        input_dir = "${params.input_dir}/"
    }

    // Create channel from input FASTA files
    fasta_ch = Channel.fromPath("${input_dir}*.fasta").splitFasta(file: true)
        .ifEmpty { error "No FASTA files found in ${input_dir}" }
    
    // Run SimpleFold prediction
    SimpleFoldInference(fasta_ch)
    
    // Emit results
    SimpleFoldInference.out.structures.view { "Generated structure: $it" }
}
