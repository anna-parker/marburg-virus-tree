reference = "config/reference.gb"
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


rule filter:
    message:
        """
        Filtering out reference sequence
        """
    input:
        sequences="data/sequences.fasta",
        metadata=rules.curate_dates.output.curated_metadata,
        exclude=dropped_strains,
    output:
        filtered_sequences="data/filtered_sequences.fasta",
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns "genbankAccession" \
            --exclude {input.exclude} \
            --output-sequences {output.filtered_sequences}
        """


rule align:
    message:
        """
        Aligning sequences to {input.reference}
          - filling gaps with N with
        """
    input:
        sequences=rules.filter.output.filtered_sequences,
        reference=reference,
    output:
        alignment="data/aligned_sequence.fasta",
    shell:
        """
        augur align \
            --sequences {input.sequences} \
            --reference-sequence {input.reference} \
            --remove-reference\
            --output {output.alignment} \
            --fill-gaps
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
            --tree-builder-args="-czb" \
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
        --clock-filter-iqd 4 \
        --date-confidence \
        --clock-rate 3.3e-4 \
        --date-inference {params.date_inference}
        """
    input:
        tree=rules.tree.output.tree,
        alignment=rules.align.output,
        metadata=rules.curate_dates.output.curated_metadata,
    output:
        tree="data/tree.nwk",
        node_data="data/branch_lengths.json",
    params:
        coalescent="opt",
        date_inference="marginal",
        root="mid_point",  #needed to have RAVN as an outgroup
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
            --timetree --max-iter 4 \
            --clock-filter-iqd 4 \
            --date-confidence \
            --clock-rate 3.3e-4 \
            --date-inference {params.date_inference} \
        """


rule ancestral:
    message:
        "Reconstructing ancestral sequences and mutations"
    input:
        tree=rules.refine.output.tree,
        alignment=rules.align.output,
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
        reference=reference,
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
        metadata=rules.curate_dates.output.curated_metadata,
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
        metadata=rules.curate_dates.output.curated_metadata,
        branch_lengths=rules.refine.output.node_data,
        traits=rules.traits.output.node_data,
        nt_muts=rules.ancestral.output.node_data,
        aa_muts=rules.translate.output.node_data,
        auspice_config=auspice_config,
        clades=rules.clades.output.node_data,
    output:
        auspice_json="auspice/marburg_tree.json",
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
