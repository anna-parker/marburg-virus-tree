# marburg-virus-tree

Nextstrain build of the Orthomarburgvirus marburgense taxon (taxonId: 3052505), with subspecies ravn virus (RAVV) and marburg virus (MARV). Alignments use the official INSDC marburg virus reference sequence [NC_001608.3](https://www.ncbi.nlm.nih.gov/nuccore/NC_001608.3).

Initial output can be viewed by pasting the results in the `auspice` folder into: https://auspice.us/.

Alternatively, you can run the build locally with:

```
micromamba create -f environment.yml
micromamba activate marburg-tree
snakemake export
```

This build uses [nextstrain/ebola](https://github.com/nextstrain/ebola) as a template.



I use 
__Gianguglielmo Zehender, Chiara Sorrentino, Carla Veo, Lisa Fiaschi, Sonia Gioffrè, Erika Ebranati, Elisabetta Tanzi, Massimo Ciccozzi, Alessia Lai, Massimo Galli,
Distribution of Marburg virus in Africa: An evolutionary approach,
Infection, Genetics and Evolution__
paper for clade names. link [here](https://www.sciencedirect.com/science/article/pii/S1567134816302386?via%3Dihub).

I additionally set the clock rate to __3.3 × 10−4__ substitutions/site/year (as inferred by Zehender et al.) as there is limited collection date information. Without specifying a clock rate timetree sometimes infers negative clock rate and otherwise infers a clock rate in the magnitude of 7e-05 (8e-06 std). The biggest impact is shifting the root from the 1300s to the 1800s. 

To give better time estimates I created time bounds using the ncbiReleaseDate as an upper bound. I initially added these in the [format expected by treetime](https://github.com/neherlab/treetime/blob/master/treetime/argument_parser.py#L84). But using the format `[lower_bound:upper_bound]` with `augur refine` results in unbounded time estimated for "bad branches" (outliers) in the magnitude of 3000c.e for samples released in the early 2000s. For now I just pass the upper_bound. This gives me reasonable time estimates. 

Initially I fixed the root to `mid_point` when calling augur refine in order to define the RAVN clade as an outgroup.
