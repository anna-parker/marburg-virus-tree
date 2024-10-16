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

Note that I had to fix the root to `mid_point` when calling augur refine - this is inorder to have the RAVN clade as an outgroup and helps with time tree inference.

I additionally set the clock rate as there is limited collection date information and when estimated during timetree inference it sometimes was estimated to be negative and otherwise was typically in the magnitude of 7e-05 (8e-06 std) leading to date inference in the years 3000. 

TODO: Figure out why augur curate format-dates is not working - then the `year-bounds` argument in agur-refine should lead to better time estimates, additionally we can use the ncbiUploadDate as an upper time bound for collectionDate. 

To give better time estimates I create time bounds using the ncbiReleaseDate as an upper bound and a lower bound of 1980. I add these in the [format expected by treetime](https://github.com/neherlab/treetime/blob/master/treetime/argument_parser.py#L84) - for some reason the format [lower_bound:upper_bound] is not working, for now I just pass the upper_bound. This gives me reasonable time estimates. 
