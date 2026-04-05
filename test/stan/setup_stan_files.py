from cmdstanpy import CmdStanModel, install_cmdstan
from pathlib import Path
import time

install_cmdstan()

DATA = {
    "y": [28, 8, -3, 7, -1, 1, 18, 12],
    "sigma": [15, 10, 16, 11, 9, 11, 10, 18],
    "J": 8,
}


def main():
    stan_file = Path(__file__).parent / "eight_schools_centred.stan"
    model = CmdStanModel(stan_file=stan_file)
    x = time.time()
    fit = model.sample(data=DATA, chains=4, iter_warmup=10, save_warmup=False,
                       iter_sampling=20, thin=1,
                       output_dir=Path(__file__).parent)


if __name__ == "__main__":
    main()
