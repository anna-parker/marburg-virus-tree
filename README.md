# marburg-virus-tree

Nextstrain build of the __Orthomarburgvirus marburgense__ species taxon (taxonId: 3052505), members of this species are called marburgviruses. However, the species has two distinct lineages: ravn virus (RAVV) and marburg virus (MARV). Alignments use the official INSDC marburg virus reference sequence [NC_001608.3](https://www.ncbi.nlm.nih.gov/nuccore/NC_001608.3).

Initial output can be viewed by pasting the results in the `auspice` folder into: https://auspice.us/.

Alternatively, you can run the build locally with:

```
micromamba create -f environment.yml
micromamba activate marburg-tree
snakemake fix_auspice_tree
```

### About 

This build uses [nextstrain/ebola](https://github.com/nextstrain/ebola) as a template.

It uses the paper: 
__Gianguglielmo Zehender, Chiara Sorrentino, Carla Veo, Lisa Fiaschi, Sonia Gioffrè, Erika Ebranati, Elisabetta Tanzi, Massimo Ciccozzi, Alessia Lai, Massimo Galli,
Distribution of Marburg virus in Africa: An evolutionary approach,
Infection, Genetics and Evolution__
for clade names; link [here](https://www.sciencedirect.com/science/article/pii/S1567134816302386?via%3Dihub). However, we choose not to show the B.1 clade as with additional samples the grouping is no longer very clear. 

- I remove all sequences that have less than 10% coverage - this is sadly over 2/3rds of the data on NIH.

- The clock rate is set to __3.3 × 10−4__ substitutions/site/year (as inferred by Zehender et al.) as there is limited collection date information. Without specifying a clock rate timetree sometimes infers negative clock rate and otherwise infers a clock rate in the magnitude of 7e-05 (8e-06 std) with a root in the 1300s or earlier. Specifying the clock ensures convergence and gives leads to accepted root time estimates in the 1800s. 

- To give better time estimates the year of the `ncbiReleaseDate` is used as an upper time bound. This gives me reasonable time estimates. However, it should be possible to give a lower and upper bound to treetime to further refine this estimate - augur just does not currently accept the [[lower_bound:upper_bound] treetime format](https://github.com/neherlab/treetime/blob/master/treetime/argument_parser.py#L84).

- I use `KX371887.3 Dianlovirus menglaense isolate Rousettus-wt/CHN/2015/Sharen-Bat9447-1, complete genome` as an outgroup to root the tree and calculate a reconstructed root of the Marburg virus tree which is used refine branch lengths. 
