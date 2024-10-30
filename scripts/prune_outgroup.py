import logging
import json
from Bio import SeqIO
from Bio import Phylo
import pandas as pd
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
@click.option("--sequences", required=True, type=click.Path(exists=True))
@click.option("--metadata", required=True, type=click.Path(exists=True))
@click.option("--reconstructed-alignments", required=True, type=click.Path(exists=True))
@click.option("--output-sequences", required=True, type=click.Path())
@click.option("--output-metadata", required=True, type=click.Path())
@click.option(
    "--log-level",
    default="INFO",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]),
)
def main(
    tree: str,
    outgroup_name: str,
    sequences: str,
    metadata: str,
    reconstructed_alignments: str,
    output_sequences: str,
    output_metadata: str,
    log_level: str,
) -> None:
    logger.setLevel(log_level)
    reconstructed_sequence_name = "ReconstructedRoot"

    tree = Phylo.read(tree, "newick")
    root_clades = tree.root.clades

    assert len(root_clades) == 2, f"Expected 2 root clades, got {len(root_clades)}"

    if root_clades[0].name == outgroup_name:
        clade_to_keep = root_clades[1]
    else:
        clade_to_keep = root_clades[0]

    with open(reconstructed_alignments, 'r') as file:
        data = json.load(file)
    reconstructed_sequence = data['nodes'][clade_to_keep.name]['sequence']

    with open(output_sequences, "w", encoding="utf-8") as output_file:
        with open(sequences, encoding="utf-8") as f_in:
            records = SeqIO.parse(f_in, "fasta")
            for record in records:
                if record.id != outgroup_name:
                    output_file.write(f">{record.description}\n{record.seq}\n")
        output_file.write(f">{reconstructed_sequence_name}\n{reconstructed_sequence}\n")

    df_all = pd.read_csv(metadata, sep="\t", encoding="utf-8")

    new_row = {'genbankAccession': reconstructed_sequence_name}

    new_row_df = pd.DataFrame([new_row])

    df = pd.concat([df_all, new_row_df], ignore_index=True)
    df.to_csv(output_metadata, sep="\t", index=False)



if __name__ == "__main__":
    main()
