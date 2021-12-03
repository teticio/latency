import os
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()
hits = 0
if 'COUNT_FILE' in os.environ:
    try:
        with open(os.environ['COUNT_FILE'], 'rt') as file:
            hits = int(file.read())
    except:
        pass


@app.get("/hits")
async def get_hits():
    global hits
    hits = hits + 1
    if 'COUNT_FILE' in os.environ:
        with open(os.environ['COUNT_FILE'], 'wt') as file:
            file.write(str(hits))
    return hits


@app.get('/healthz')
async def health_check():
    return {'status': 'pass'}


app.mount('/', StaticFiles(directory='common', html=True), name='index')
