#!/usr/bin/python3

import tomllib
import argparse
import pathlib

ROOT = pathlib.Path(__file__).parent

def parse_args() -> tuple[str, dict]:
    args = argparse.ArgumentParser("generate")
    args.add_argument("--file", "-f", help="The caplist to load.", default=ROOT/'caplist.toml')

    subs = args.add_subparsers()

    lst = subs.add_parser("list")
    lst.set_defaults(cmd="list")

    parsed = args.parse_args()
    with open(parsed.file, 'rb') as f:
        return parsed.cmd, tomllib.load(f)

def main():
    cmd, loaded = parse_args()
    print(cmd, loaded)


if __name__ == "__main__":
    main()
