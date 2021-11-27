from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

app = FastAPI()
hits = 0


@app.get("/hits")
async def get_hits():
    global hits
    hits = hits + 1
    return hits

app.mount('/', StaticFiles(directory='common', html=True), name='index')
