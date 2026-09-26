import gradio as gr
from main import app as fastapi_app

# Interactive dashboard for Hugging Face Space viewer
with gr.Blocks(title="DilSe Music Backend") as demo:
    gr.Markdown("# 🎵 DilSe Music Cloud Backend")
    gr.Markdown("### ✅ Status: **ONLINE**")
    gr.Markdown("All API endpoints (`/jio/search`, `/lyrics`, `/jio/suggestions`, `/version`) are live and operational.")

# Mount the Gradio interface onto our existing FastAPI application
app = gr.mount_gradio_app(fastapi_app, demo, path="/")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)
