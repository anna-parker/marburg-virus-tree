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
@click.option("--all-sequences", required=True, type=click.Path(exists=True))
@click.option("--all-metadata", required=True, type=click.Path(exists=True))
@click.option("--dropped-strains", required=True, type=click.Path(exists=True))
@click.option("--prealigned-sequences", required=True, type=click.Path(exists=True))
@click.option("--prealigned-tsv", required=True, type=click.Path(exists=True))
@click.option("--output-sequences", required=True, type=str)
@click.option("--output-metadata", required=True, type=str)
@click.option("--min-coverage", default=0.1, type=float)
@click.option(
    "--log-level",
    default="INFO",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]),
)
def main(
    all_sequences: str,
    all_metadata: str,
    dropped_strains: str,
    prealigned_sequences: str,
    prealigned_tsv: str,
    output_sequences: str,
    output_metadata: str,
    min_coverage: float,
    log_level: str,
) -> None:
    logger.setLevel(log_level)

    df = pd.read_csv(prealigned_tsv, sep="\t", encoding="utf-8")
    too_low_coverage = df[df["coverage"] <= min_coverage]["seqName"].tolist()
    too_low_coverage = [name.split()[0] for name in too_low_coverage]
    logger.info(
        f"Found {len(too_low_coverage)} strains with coverage under {min_coverage}"
    )

    with open(dropped_strains, "r") as file:
        dropped_strain_list = file.read().splitlines()
    dropped_strain_list = [name.split()[0] for name in dropped_strain_list]

    logger.info(
        f"Additionally dropping {len(dropped_strain_list)} strains: {dropped_strain_list}"
    )

    prealigned_ids = set()
    with open(prealigned_sequences, encoding="utf-8") as f_in:
        prealigned_records = SeqIO.parse(f_in, "fasta")
        for record in prealigned_records:
            prealigned_ids.add(record.id)
    logger.info(f"Found {len(prealigned_ids)} strains that aligned to reference")

    keep = []

    count = 0
    with open(output_sequences, "w", encoding="utf-8") as output_file:
        with open(all_sequences, encoding="utf-8") as f_in:
            records = SeqIO.parse(f_in, "fasta")
            for record in records:
                count += 1
                if record.id not in prealigned_ids:
                    continue
                if record.id in too_low_coverage:
                    continue
                if record.id in dropped_strain_list:
                    continue
                output_file.write(f">{record.description}\n{record.seq}\n")
                keep.append(record.id)

    logger.info(f"Kept {len(keep)} strains out of {count} total strains")

    df_all = pd.read_csv(all_metadata, sep="\t", encoding="utf-8")
    filtered_df = df_all[df_all["genbankAccession"].isin(keep)]
    filtered_df.to_csv(output_metadata, sep="\t", index=False)


if __name__ == "__main__":
    main()