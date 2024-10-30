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
            #del children[i]
            child['name'] = "Reconstructed Root using KX371887.3: Dianlovirus menglaense as Outgroup"
            break

    #data['tree']['name'] = "Reconstructed Root using KX371887.3: Dianlovirus menglaense as Outgroup"

    with open(output_auspice_tree, 'w') as file:
        json.dump(data, file, indent=4)

    print("Renamed root successfully.")



if __name__ == "__main__":
    main()
