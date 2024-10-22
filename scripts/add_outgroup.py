import logging
import pandas as pd

import click
from Bio import SeqIO


logger = logging.getLogger(__name__)
logging.basicConfig(
    encoding="utf-8",
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)8s (%(filename)20s:%(lineno)4d) - %(message)s ",
    datefmt="%H:%M:%S",
)


@click.command(help="Parse fasta header, only keep if fits regex filter_fasta_headers")
@click.option("--sequences", required=True, type=click.Path(exists=True))
@click.option("--metadata", required=True, type=click.Path(exists=True))
@click.option("--outgroup", required=True, type=click.Path(exists=True))
@click.option("--output-sequences", required=True, type=str)
@click.option("--output-metadata", required=True, type=str)
@click.option(
    "--log-level",
    default="INFO",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]),
)
def main(
    sequences: str,
    metadata: str,
    outgroup: str,
    output_sequences: str,
    output_metadata: str,
    log_level: str,
) -> None:
    logger.setLevel(log_level)

    outgroup_name = ""

    with open(output_sequences, "w", encoding="utf-8") as output_file:
        with open(sequences, encoding="utf-8") as f_in:
            records = SeqIO.parse(f_in, "fasta")
            for record in records:
                output_file.write(f">{record.description}\n{record.seq}\n")
        with open(outgroup, encoding="utf-8") as f_in:
            records = SeqIO.parse(f_in, "fasta")
            for record in records:
                output_file.write(f">{record.description}\n{record.seq}\n")
                outgroup_name = record.id

    df_all = pd.read_csv(metadata, sep="\t", encoding="utf-8")
    new_row = {'genbankAccession': outgroup_name}

    new_row_df = pd.DataFrame([new_row])

    df = pd.concat([df_all, new_row_df], ignore_index=True)
    df.to_csv(output_metadata, sep="\t", index=False)


if __name__ == "__main__":
    main()
