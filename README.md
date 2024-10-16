# marburg-virus-tree

Marburg virus auspice tree built using [NC_001608.3](https://www.ncbi.nlm.nih.gov/nuccore/NC_001608.3) as the reference.

Snakemake uses [nextstrain/ebola](https://github.com/nextstrain/ebola) as a template. Build can be run using:

```
micromamba create -f environment.yml
micromamba activate marburg-tree
snakemake export
```

Initial output can be viewed by pasting the results in the `auspice` folder into: https://auspice.us/.

Sequences contain all sequences downloaded from https://www.ncbi.nlm.nih.gov/labs/virus/vssi/#/virus?SeqType_s=Nucleotide&VirusLineage_ss=Orthomarburgvirus%20marburgense,%20taxid:3052505.
