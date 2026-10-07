import os

from dotenv import load_dotenv
from sqlalchemy import create_engine


load_dotenv()


def get_oltp_engine():
    url = (
        f"postgresql+psycopg://"
        f"{os.getenv('OLTP_USER')}:"
        f"{os.getenv('OLTP_PASSWORD')}@"
        f"{os.getenv('OLTP_HOST')}:"
        f"{os.getenv('OLTP_PORT')}/"
        f"{os.getenv('OLTP_DB')}"
    )

    return create_engine(url)


def get_dw_engine():
    url = (
        f"postgresql+psycopg://"
        f"{os.getenv('DW_USER')}:"
        f"{os.getenv('DW_PASSWORD')}@"
        f"{os.getenv('DW_HOST')}:"
        f"{os.getenv('DW_PORT')}/"
        f"{os.getenv('DW_DB')}"
    )

    return create_engine(url)