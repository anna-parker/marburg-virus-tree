from datetime import datetime
import logging
import csv

import click
import pytz
import dateutil.parser as dateutil



logger = logging.getLogger(__name__)
logging.basicConfig(
    encoding="utf-8",
    level=logging.DEBUG,
    format="%(asctime)s %(levelname)8s (%(filename)20s:%(lineno)4d) - %(message)s ",
    datefmt="%H:%M:%S",
)


@click.command(help="Parse fasta header, only keep if fits regex filter_fasta_headers")
@click.option("--input-metadata", required=True, type=click.Path(exists=True))
@click.option("--output-metadata", required=True, type=click.Path())
@click.option("--collection-date-field", required=True, type=str)
@click.option("--upper-bound-field", required=True, type=str)
@click.option("--output-field", required=True, type=str)
@click.option(
    "--log-level",
    default="INFO",
    type=click.Choice(["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]),
)
def main(
    input_metadata: str,
    output_metadata: str,
    collection_date_field: str,
    upper_bound_field: str,
    output_field: str,
    log_level: str,
) -> None:
    logger.setLevel(log_level)

    logger.info(f"Reading metadata from {input_metadata}")
    with open(input_metadata, mode='r', newline='', encoding='utf-8') as tsv_file:
        reader = csv.DictReader(tsv_file, delimiter='\t')
        metadata_dict = [row for row in reader]

    formats_to_try = ["%Y-%m-%d", "%Y-%m", "%Y"]
    lower_bound = 1980
    upper_bound = 2024

    ## If collection date field is empty replace with [1980:upper-bound-field]
    for record in metadata_dict:
        record[output_field] = None
        if record[collection_date_field]:
            for format in formats_to_try:
                try:
                    parsed_date = datetime.strptime(record[collection_date_field], format)
                    match format:
                        case "%Y-%m-%d":
                            datum = parsed_date.strftime("%Y-%m-%d")
                        case "%Y-%m":
                            datum = f"{parsed_date.strftime('%Y-%m')}-XX"
                        case "%Y":
                            datum = f"{parsed_date.strftime('%Y')}-XX-XX"
                    record[output_field] = datum
                except ValueError:
                    continue
        if record[output_field]:
            continue
        if record[upper_bound_field]:
            try:
                parsed_timestamp = dateutil.parse(record[upper_bound_field])
                #upper_bound = parsed_timestamp.strftime('%Y')
                upper_bound = f"{parsed_timestamp.strftime('%Y')}-XX-XX"
            except ValueError:
                continue
        #record[output_field] = f"[{lower_bound}:{upper_bound}]"
        record[output_field] = upper_bound

    logger.info(f"Writing metadata to {output_metadata}")
    fieldnames = metadata_dict[0].keys()

    with open(output_metadata, mode='w', newline='', encoding='utf-8') as tsv_file:
        writer = csv.DictWriter(tsv_file, fieldnames=fieldnames, delimiter='\t')

        writer.writeheader()
        writer.writerows(metadata_dict)




if __name__ == "__main__":
    main()
