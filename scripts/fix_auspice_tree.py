import logging
import json

import click



logger = logging.getLogger(__name__)
logging.basicConfig(
    encoding="utf-8",
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)8s (%(filename)20s:%(lineno)4d) - %(message)s ",
    datefmt="%H:%M:%S",
)

def add_lineage(node):
    if "children" in node:
        for child in node["children"]:
            add_lineage(child)
    full_clade_name = node["node_attrs"]["clade_membership"]["value"]
    lineage = None
    if full_clade_name.startswith("MARV"):
        lineage = "MARV"
    if full_clade_name.startswith("RAVV"):
        lineage = "RAVV"
    if lineage:
        node["node_attrs"]["lineage"] = {}
        node["node_attrs"]["lineage"]["value"] = lineage


@click.command(help="Drops the outgroup from the auspice-tree")
@click.option("--auspice-tree", required=True, type=click.Path(exists=True))
@click.option("--outgroup-name", required=True, type=str)
@click.option("--output-auspice-tree", required=True, type=str)
@click.option(
    "--log-level",
    default="INFO",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]),
)
def main(
    auspice_tree: str,
    output_auspice_tree: str,
    outgroup_name: str,
    log_level: str,
) -> None:
    logger.setLevel(log_level)

    with open(auspice_tree, 'r') as file:
        data = json.load(file)

    children = data['tree']['children']
    for i, child in enumerate(children):
        if child["name"] == outgroup_name:
            #del children[i] # Keep the outgroup for now as this is the reconstructed root
            child['name'] = "Reconstructed Root using KX371887.3: Dianlovirus menglaense as Outgroup"
            break
    #data['tree']['name'] = "Reconstructed Root using KX371887.3: Dianlovirus menglaense as Outgroup"

    print("Renamed outgroup successfully.")

    add_lineage(data['tree'])

    print("Added lineage information to nodes successfully.")

    data["meta"]["colorings"] = data["meta"]["colorings"] + [{
                "key": "lineage",
                "title": "Lineage",
                "type": "categorical"
            }]


    with open(output_auspice_tree, 'w') as file:
        json.dump(data, file, indent=4)



if __name__ == "__main__":
    main()
