import logging
import json
from Bio import Phylo

import click



logger = logging.getLogger(__name__)
logging.basicConfig(
    encoding="utf-8",
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)8s (%(filename)20s:%(lineno)4d) - %(message)s ",
    datefmt="%H:%M:%S",
)


@click.command(help="Drops the outgroup from the refine tree")
@click.option("--tree", required=True, type=click.Path(exists=True))
@click.option("--outgroup-name", required=True, type=str)
@click.option("--branch-lengths-json", required=True, type=click.Path(exists=True))
@click.option("--output-tree", required=True, type=click.Path())
@click.option("--output-branch-lengths-json", required=True, type=click.Path())
@click.option(
    "--log-level",
    default="INFO",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]),
)
def main(
    tree: str,
    outgroup_name: str,
    branch_lengths_json: str,
    output_tree: str,
    output_branch_lengths_json: str,
    log_level: str,
) -> None:
    logger.setLevel(log_level)

    tree = Phylo.read(tree, "newick")
    root_clades = tree.root.clades

    root_name = tree.root.name
    assert len(root_clades) == 2, f"Expected 2 root clades, got {len(root_clades)}"

    if root_clades[0].name == outgroup_name:
        clade_to_keep = root_clades[1]
        clade_to_delete = root_clades[0]
    else:
        clade_to_keep = root_clades[0]
        clade_to_delete = root_clades[1]

    tree.root.clades.remove(clade_to_delete)
    tree.root.branch_length = 0
    clade_to_keep.branch_length = 0

    Phylo.write(tree, output_tree, "newick")
    logger.info(f"Dropped outgroup {outgroup_name} successfully from .nwk.")

    with open(branch_lengths_json, 'r') as file:
        data = json.load(file)

    data['nodes'][clade_to_keep.name]['branch_length'] = 0
    data['nodes'][clade_to_keep.name]['clock_length'] = 0
    data['nodes'][clade_to_keep.name]['mutation_length'] = 0
    logger.info(f"Set branch_length, clock_length and mutation_length to 0 for {clade_to_keep.name}.")

    data['nodes'][root_name] = data['nodes'][clade_to_keep.name]

    del data['nodes'][outgroup_name]
    logger.info(f"Dropped {outgroup_name} successfully from json.")

    with open(output_branch_lengths_json, 'w') as file:
        json.dump(data, file, indent=4)



if __name__ == "__main__":
    main()
