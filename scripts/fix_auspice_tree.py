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

    # delete the outgroup
    for i, child in enumerate(children):
        if child["name"] == outgroup_name:
            del children[i]
            break

    children = data['tree']['children']
    assert len(children) == 1, f"Expected 1 child, got {len(children)}"
    div = children[0]["node_attrs"]["div"]
    time_first_inner_node =  children[0]["node_attrs"]["num_date"]["value"]
    logger.info(f"First child has div:{div}, shrinking")
    logger.info(f"First child has time:{time_first_inner_node}, shrinking")

    # shrink long branch to root
    data['tree']["node_attrs"]["num_date"]["value"] = time_first_inner_node - 10
    data['tree']["node_attrs"]["num_date"]["confidence"] = [time_first_inner_node - 10, time_first_inner_node]

    # remove div from all children
    def traverse(node):
        if 'children' in node:
            for child in node['children']:
                child['node_attrs']['div'] -= div
                traverse(child)

    traverse(data['tree'])

    with open(output_auspice_tree, 'w') as file:
        json.dump(data, file, indent=4)

    print(f"Dropped {outgroup_name} successfully.")


if __name__ == "__main__":
    main()
