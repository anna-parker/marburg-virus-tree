reference_gff3 = "config/reference.gff3"
reference = "config/reference.fasta"
outgroup = "config/menglaense_sequence.fasta"
outgroup_name = "KX371887.3"
dropped_strains = "config/dropped_strains.txt"
colors = ("config/colors.tsv",)

auspice_config = "config/auspice_config.json"
TAXON_ID = 3052505

COLUMN_MAPPING = {
    "Accession": "genbankAccession",
    "BioProjects": "bioprojects",
    "BioSample accession": "biosampleAccession",
    "Gene count": "ncbi_gene_count",
    "Geographic Location": "ncbiGeoLocation",
    "Geographic Region": "ncbiGeoRegion",
    "Host Common Name": "ncbiHostCommonName",
    "Host Infraspecific Names Breed": "ncbiHostBreed",
    "Host Infraspecific Names Cultivar": "ncbiHostCultivar",
    "Host Infraspecific Names Ecotype": "ncbiHostEcotype",
    "Host Infraspecific Names Isolate": "ncbiHostIsolate",
    "Host Infraspecific Names Sex": "ncbiHostSex",
    "Host Infraspecific Names Strain": "ncbiHostStrain",
    "Host Name": "ncbiHostName",
    "Host Pangolin Classification": "ncbiHostPangolin",
    "Host Taxonomic ID": "ncbiHostTaxId",
    "Is Annotated": "ncbiIsAnnotated",
    "Is Complete": "ncbiIsComplete",
    "Is Lab Host": "ncbiIsLabHost",
    "Is Vaccine Strain": "ncbiIsVaccineStrain",
    "Isolate Collection date": "ncbiCollectionDate",
    "Isolate Lineage": "ncbiIsolateName",
    "Isolate Lineage source": "ncbiIsolateSource",
    "Lab Host": "ncbiLabHost",
    "Mature peptide count": "ncbiMaturePeptideCount",
    "Molecule type": "ncbiMolType",
    "Protein count": "ncbiProteinCount",
    "Purpose of Sampling": "ncbiPurposeOfSampling",
    "Release date": "ncbiReleaseDate",
    "Source database": "ncbiSourceDb",
    "SRA Accessions": "ncbiSraAccessions",
    "Submitter Affiliation": "ncbiSubmitterAffiliation",
    "Submitter Country": "ncbiSubmitterCountry",
    "Submitter Names": "author",
    "Update date": "ncbiUpdateDate",
    "Virus Common Name": "ncbiVirusCommonName",
    "Virus Infraspecific Names Breed": "ncbiVirusBreed",
    "Virus Infraspecific Names Cultivar": "ncbiVirusCultivar",
    "Virus Infraspecific Names Ecotype": "ncbiVirusEcotype",
    "Virus Infraspecific Names Isolate": "ncbiVirusIsolate",
    "Virus Infraspecific Names Sex": "ncbi_virus",
    "Virus Infraspecific Names Strain": "ncbiVirusStrain",
    "Virus Name": "ncbiVirusName",
    "Virus Pangolin Classification": "ncbiVirusPangolin",
    "Virus Taxonomic ID": "ncbiVirusTaxId",
}


# TODO: replace this with `augur curate rename`
def rename_columns(input_file, output_file, mapping=COLUMN_MAPPING):
    with open(input_file, "r") as f:
        header = f.readline().strip().split("\t")
        header = [mapping.get(h, h) for h in header]
        with open(output_file, "w") as g:
            g.write("\t".join(header) + "\n")
            for line in f:
                g.write(line)


rule fetch_ncbi_dataset_package:
    output:
        dataset_package="data/ncbi_dataset.zip",
    shell:
        """
        datasets download virus genome taxon {TAXON_ID} \
            --no-progressbar \
            --filename {output.dataset_package} \
        """


rule extract_ncbi_dataset_sequences:
    input:
        dataset_package=rules.fetch_ncbi_dataset_package.output.dataset_package,
    output:
        ncbi_dataset_sequences="data/sequences.fasta",
    shell:
        """
        unzip -jp {input.dataset_package} ncbi_dataset/data/genomic.fna > {output.ncbi_dataset_sequences}
        """


rule format_ncbi_dataset_report:
    input:
        dataset_package=rules.fetch_ncbi_dataset_package.output.dataset_package,
    output:
        ncbi_dataset_tsv="data/metadata_post_extract.tsv",
    shell:
        """
        dataformat tsv virus-genome \
            --package {input.dataset_package} \
            > {output.ncbi_dataset_tsv}
        """


rule rename_columns:
    input:
        ncbi_dataset_tsv="data/metadata_post_extract.tsv",
    output:
        ncbi_dataset_tsv="data/metadata_post_rename.tsv",
    params:
        mapping=COLUMN_MAPPING,
    run:
        rename_columns(
            input.ncbi_dataset_tsv, output.ncbi_dataset_tsv, mapping=params.mapping
        )


rule curate_metadata_geolocation:
    input:
        metadata="data/metadata_post_rename.tsv",
    output:
        precurated_metadata="data/pre_metadata_curated.tsv",
        curated_metadata="data/geoloc_metadata_curated.tsv",
    shell:
        """
        augur curate parse-genbank-location --metadata {input.metadata} --location-field='ncbiGeoLocation' --output-metadata {output.precurated_metadata}
        augur curate apply-geolocation-rules --metadata {output.precurated_metadata} --geolocation-rules config/gisaid_geoLocationRules.tsv --output-metadata {output.curated_metadata} --region-field='ncbiGeoRegion'
        """


rule curate_dates:
    input:
        metadata="data/geoloc_metadata_curated.tsv",
    output:
        curated_metadata="data/metadata_curated.tsv",
    shell:
        """
        python scripts/curate_dates.py --input-metadata {input.metadata} \
            --output-metadata {output.curated_metadata} \
            --collection-date-field='ncbiCollectionDate' \
            --upper-bound-field='ncbiReleaseDate' \
            --output-field='date'
        """


rule prealign:
    input:
        sequences="data/sequences.fasta",
        reference=reference,
    output:
        prealigned_fasta="data/prealigned_sequences.fasta",
        prealigned_tsv="data/prealigned_nextclade.tsv",
    shell:
        """
        nextclade run \
        --retry-reverse-complement \
        --input-ref={input.reference} \
        --output-fasta={output.prealigned_fasta} \
        --output-tsv={output.prealigned_tsv} \
        {input.sequences}
        """


rule filter:
    message:
        """
        Filter out dropped strains, sequences with coverage 
        under 0.1 and sequences that failed prealignment
        """
    input:
        sequences="data/sequences.fasta",
        metadata=rules.curate_dates.output.curated_metadata,
        exclude=dropped_strains,
        prealigned_fasta="data/prealigned_sequences.fasta",
        prealigned_tsv="data/prealigned_nextclade.tsv",
    output:
        filtered_sequences="data/filtered_sequences.fasta",
        filtered_metadata="data/filtered_metadata.tsv",
    params:
        min_coverage=0.1,
    shell:
        """
        python scripts/filter.py \
            --all-sequences {input.sequences} \
            --all-metadata {input.metadata} \
            --dropped-strains {input.exclude} \
            --prealigned-sequences {input.prealigned_fasta} \
            --prealigned-tsv {input.prealigned_tsv} \
            --output-sequences {output.filtered_sequences} \
            --output-metadata {output.filtered_metadata} \
            --min-coverage {params.min_coverage}
        """


rule add_outgroup:
    message:
        "Adding outgroup to metadata"
    input:
        outgroup=outgroup,
        metadata=rules.filter.output.filtered_metadata,
        sequences=rules.filter.output.filtered_sequences,
    output:
        sequences="data/sequences_with_outgroup.fasta",
        metadata="data/metadata_with_outgroup.tsv",
    shell:
        """
        python scripts/add_outgroup.py \
            --metadata {input.metadata} \
            --sequences {input.sequences} \
            --outgroup {input.outgroup} \
            --output-metadata {output.metadata} \
            --output-sequences {output.sequences}
        """


rule align:
    message:
        """
        Aligning sequences to {input.reference}
        """
    input:
        sequences=rules.add_outgroup.output.sequences,
        reference=reference,
    output:
        alignment="data/aligned_sequence.fasta",
    shell:
        """
        nextclade run \
        --min-seed-cover=0.01 \
        --kmer-length=7 \
        --allowed-mismatches=10 \
        --penalty-gap-open=18 \
        --penalty-gap-open-in-frame=18 \
        --penalty-gap-open-out-of-frame=18 \
        --gap-alignment-side=left \
        --retry-reverse-complement \
        --input-ref={input.reference} \
        --output-fasta={output.alignment} \
        --include-reference=true \
        {input.sequences}
        """


rule tree:
    message:
        "Building tree"
    input:
        alignment=rules.align.output.alignment,
    output:
        tree="data/tree_raw.nwk",
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --tree-builder-args="-czb -o KX371887.3"\
            --output {output.tree}
        """


rule prerefine:
    message:
        """
        Refining tree
          - estimate timetree
          - use {params.coalescent} coalescent timescale
          - estimate {params.date_inference} node dates
        Papers estimate the clock rate at 3.3e-4 subs/site/year
        """
    input:
        tree=rules.tree.output.tree,
        alignment=rules.align.output,
        metadata=rules.add_outgroup.output.metadata,
    output:
        tree="data/pre_tree.nwk",
        node_data="data/pre_branch_lengths.json",
    params:
        coalescent="opt",
        date_inference="marginal",
        root=outgroup_name,  #needed to have RAVN as an outgroup
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --metadata-id-columns genbankAccession \
            --coalescent {params.coalescent} \
            --root {params.root} \
            --timetree --max-iter 4 \
            --date-confidence \
            --clock-rate 3.3e-4 \
            --date-inference {params.date_inference} \
        """


rule preancestral:
    message:
        "Reconstructing ancestral sequences and mutations"
    input:
        tree=rules.prerefine.output.tree,
        alignment=rules.align.output,
        reference=reference,
    output:
        node_data="data/pre_nt_muts.json",
    params:
        inference="joint",
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --root-sequence {input.reference} \
            --inference {params.inference}
        """


rule prune_outgroup:
    message:
        "Pruning outgroup and root branch"
    input:
        tree=rules.prerefine.output.tree,
        alignment=rules.align.output,
        metadata=rules.add_outgroup.output.metadata,
        node_data=rules.preancestral.output.node_data,
        scripts="scripts/prune_outgroup.py",
    output:
        alignment="data/aligned_sequences_pruned.fasta",
        metadata="data/metadata_pruned.tsv",
    shell:
        """
        python {input.scripts} \
            --tree {input.tree} \
            --outgroup-name {outgroup_name} \
            --sequences {input.alignment} \
            --metadata {input.metadata} \
            --reconstructed-alignments {input.node_data} \
            --output-sequences {output.alignment} \
            --output-metadata {output.metadata} \
        """

rule rooted_tree:
    message:
        "Build tree with reconstructed root"
    input:
        alignment=rules.prune_outgroup.output.alignment,
    output:
        tree="data/rooted_tree.nwk",
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --tree-builder-args="-czb -o ReconstructedRoot"\
            --output {output.tree}
        """


rule refine:
    message:
        """
        Refining tree
          - estimate timetree
          - use {params.coalescent} coalescent timescale
          - estimate {params.date_inference} node dates
        Papers estimate the clock rate at 3.3e-4 subs/site/year
        """
    input:
        tree=rules.rooted_tree.output.tree,
        alignment=rules.prune_outgroup.output.alignment,
        metadata=rules.prune_outgroup.output.metadata,
    output:
        tree="data/tree.nwk",
        node_data="data/branch_lengths.json",
    params:
        coalescent="opt",
        date_inference="marginal",
        root="ReconstructedRoot"
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --output-tree {output.tree} \
            --output-node-data {output.node_data} \
            --metadata-id-columns genbankAccession \
            --coalescent {params.coalescent} \
            --root {params.root} \
            --timetree --max-iter 4 \
            --date-confidence \
            --clock-rate 3.3e-4 \
            --date-inference {params.date_inference} \
        """


rule ancestral:
    message:
        "Reconstructing ancestral sequences and mutations"
    input:
        tree=rules.refine.output.tree,
        alignment=rules.prune_outgroup.output.alignment,
        reference=reference,
    output:
        node_data="data/nt_muts.json",
    params:
        inference="joint",
    shell:
        """
        augur ancestral \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --output-node-data {output.node_data} \
            --root-sequence {input.reference} \
            --inference {params.inference}
        """


rule translate:
    message:
        "Translating amino acid sequences"
    input:
        tree=rules.refine.output.tree,
        node_data=rules.ancestral.output.node_data,
        reference=reference_gff3,
    output:
        node_data="data/aa_muts.json",
    shell:
        """
        augur translate \
            --tree {input.tree} \
            --ancestral-sequences {input.node_data} \
            --reference-sequence {input.reference} \
            --output-node-data {output.node_data} \
        """


rule clades:
    message:
        "Adding internal clade labels"
    input:
        tree=rules.refine.output.tree,
        aa_muts=rules.translate.output.node_data,
        nuc_muts=rules.ancestral.output.node_data,
        clades="config/clades.tsv",
    output:
        node_data="data/clades_raw.json",
    shell:
        """
        augur clades \
            --tree {input.tree} \
            --mutations {input.nuc_muts} {input.aa_muts} \
            --clades {input.clades} \
            --output-node-data {output.node_data} 2>&1 | tee {log}
        """


rule traits:
    message:
        "Inferring ancestral traits for {params.columns!s}"
    input:
        tree=rules.refine.output.tree,
        metadata=rules.prune_outgroup.output.metadata,
    output:
        node_data="data/traits.json",
    params:
        columns="ncbiVirusTaxId country ncbiGeoRegion",
    shell:
        """
        augur traits \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --output-node-data {output.node_data} \
            --columns {params.columns} \
            --confidence \
            --metadata-id-columns genbankAccession
        """


rule export:
    message:
        "Exporting data files for for auspice"
    input:
        tree=rules.refine.output.tree,
        metadata=rules.prune_outgroup.output.metadata,
        branch_lengths=rules.refine.output.node_data,
        traits=rules.traits.output.node_data,
        nt_muts=rules.ancestral.output.node_data,
        aa_muts=rules.translate.output.node_data,
        auspice_config=auspice_config,
        clades=rules.clades.output.node_data,
    output:
        auspice_json="data/marburg_tree.json",
    params:
        id_column="genbankAccession",
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --metadata {input.metadata} \
            --node-data {input.branch_lengths} {input.traits} {input.nt_muts} {input.aa_muts} {input.clades} \
            --auspice-config {input.auspice_config} \
            --output {output.auspice_json} \
            --include-root-sequence \
            --metadata-id-columns {params.id_column}
        """

rule fix_auspice_tree:
    message:
        "Rename root"
    input:
        auspice_tree=rules.export.output.auspice_json,
    params:
        outgroup="ReconstructedRoot",
    output:
        auspice_tree="auspice/marburg_tree.json",
    shell:
        """
        python scripts/fix_auspice_tree.py \
            --auspice-tree {input.auspice_tree} \
            --output-auspice-tree {output.auspice_tree} \
            --outgroup-name {params.outgroup}
        """