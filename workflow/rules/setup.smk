import copy
from pathlib import Path
import tempfile
from snakebids import bids, generate_inputs, filter_list
from snakeboost import PipEnv, Boost, Pyscript
import os

# Get input wildcards
inputs = generate_inputs(
    bids_dir=config["bids_dir"],
    pybids_inputs=config["pybids_inputs"],
    pybids_database_dir=config.get("pybids_db_dir"),
    pybids_reset_database=config.get("pybids_db_reset"),
    derivatives=config.get("derivatives", None),
    participant_label=config.get("participant_label", None),
    exclude_participant_label=config.get("exclude_participant_label", None),
)

if "t1w_echo" in inputs and "t1w" in inputs and (
    set(inputs["t1w_echo"].wildcards) - set(inputs["t1w"].wildcards)
) != {"echo"}:
    raise ValueError(
        "t1w_echo and t1w components must have the same wildcards, besides 'echo'"
    )

out = Path(config["output_dir"])
uid = Path(bids(**inputs.subj_wildcards)).name
work = Path(config["output_dir"]) / 'work'
tmp = Path(os.environ.get("SLURM_TMPDIR", tempfile.mkdtemp(prefix="snakeanat.")))

boost = Boost(work, logger)

# is there a better fallback if PIP_WHEEL_DIR isn't set? maybe not define a wheelhouse
# at all?
wheelhouse = os.environ.get('PIP_WHEEL_DIR','~/projects/ctb-akhanf/knavynde/wheels/')

pyscript = Pyscript(workflow.basedir)
pathxf_venv = PipEnv(
    root=tmp,
    flags=f"--no-index -f {wheelhouse}",
    packages=[
        "pathxf==0.0.3.dev1+91cb9eb"
    ]
)

simpleitk_env = PipEnv(
    root=tmp,
    flags=f"--no-index -f {wheelhouse}",
    packages=[
        "SimpleItk==2.2.1",
        "snakeboost",
    ]
)

sourcedata = out/"sourcedata"
