// © 2025 BioTeam, LLC All rights reserved.
// AWS HealthOmics Configuration for SimpleFold
// Template placeholders will be replaced by setup.sh

params {
    // Input configuration
    input_dir = 's3://${S3_BUCKET_NAME}/input/'
    
    // SimpleFold parameters
    simplefold_model = 'simplefold_100M'
    num_steps = 500
    tau = 0.01
    nsample_per_protein = 1
    enable_plddt = true
}

// Process configuration
process {
    // Default container
    container = '${ECR_URI}'    
    
    // Container labels
    withLabel: 'simplefold_container' {
        container = '${ECR_URI}'
    }
}

// Workflow metadata
manifest {
    name = 'SimpleFold for AWS HealthOmics'
    author = '${AUTHOR_NAME}'
    description = 'Protein structure prediction using Apple SimpleFold'
    mainScript = 'main.nf'
    version = '1.0.0'
    nextflowVersion = '>=22.04.0'
}
