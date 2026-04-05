# Stan CSV files for testing FlexiChains

The Python script here generates four Stan CSV files, which are also committed to the repo.

To regenerate the data (if necessary):

```bash
python -m venv venv
source ./venv/bin/activate
python -m pip install cmdstanpy
python setup_stan_files.py
```
