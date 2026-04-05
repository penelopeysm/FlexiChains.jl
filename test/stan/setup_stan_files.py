from cmdstanpy import CmdStanModel, install_cmdstan
from pathlib import Path
import time

install_cmdstan()

DATA = {
    "y": [28, 8, -3, 7, -1, 1, 18, 12],
    "sigma": [15, 10, 16, 11, 9, 11, 10, 18],
    "J": 8,
}

DIRNAME = Path(__file__).parent

MODEL_NAME = "eight_schools_centred"

def main():
    # Delete all old CSV files
    for f in DIRNAME.glob("*.csv"):
        f.unlink()
    # Sample a new one
    stan_file = DIRNAME / f"{MODEL_NAME}.stan"
    model = CmdStanModel(stan_file=stan_file)
    fit = model.sample(data=DATA, chains=4, iter_warmup=10, save_warmup=False,
                       iter_sampling=20, thin=2,
                       output_dir=DIRNAME)
    # Rename the existing ones
    for f in DIRNAME.glob("*.csv"):
        chain_number_dot_csv = f.name.split("_")[-1]
        new_name = f"{MODEL_NAME}_{chain_number_dot_csv}"
        f.rename(f.parent / new_name)
    # Clean up logs
    for f in DIRNAME.glob("*.txt"):
        f.unlink()

if __name__ == "__main__":
    main()
