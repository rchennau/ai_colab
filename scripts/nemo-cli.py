#!/usr/bin/env python3
import os
import sys
import argparse
import subprocess
import time
from openai import OpenAI

def report_error(error_msg):
    """Report error status to the Blackboard for Fleet Autonomy."""
    agent_name = os.environ.get("HCOM_NAME")
    if not agent_name:
        return
    
    script_dir = os.path.dirname(os.path.realpath(__file__))
    kv_tool = os.path.join(script_dir, "hcom-kv.sh")
    
    if os.path.exists(kv_tool):
        # Escape quotes for JSON
        safe_msg = str(error_msg).replace('"', '\\"')
        timestamp = int(time.time())
        health_data = f'{{"status":"error","message":"{safe_msg}","ts":{timestamp}}}'
        try:
            subprocess.run([kv_tool, "set", f"fleet_health_{agent_name}", health_data], 
                           capture_output=True, check=False)
        except Exception:
            pass

def main():
    parser = argparse.ArgumentParser(description="NVIDIA NeMo CLI Wrapper")
    parser.add_argument("-m", "--model", default="nvidia/llama-3.3-nemotron-super-49b-v1.5", help="Model name")
    parser.add_argument("-p", "--prompt", help="Prompt text")
    parser.add_argument("--system-prompt", help="System prompt")
    parser.add_argument("query", nargs="*", help="Positional query")

    args, unknown = parser.parse_known_args()

    api_key = os.environ.get("NVIDIA_API_KEY")
    if not api_key:
        print("Error: NVIDIA_API_KEY environment variable not set.")
        sys.exit(1)

    base_url = os.environ.get("NEMO_BASE_URL", "https://integrate.api.nvidia.com/v1")
    client = OpenAI(
        base_url=base_url,
        api_key=api_key
    )

    query_text = " ".join(args.query)
    if args.prompt:
        query_text = args.prompt + " " + query_text

    messages = []
    if args.system_prompt:
        messages.append({"role": "system", "content": args.system_prompt})
    
    messages.append({"role": "user", "content": query_text})

    try:
        completion = client.chat.completions.create(
            model=args.model,
            messages=messages,
            temperature=0.5,
            top_p=1,
            max_tokens=1024,
            stream=True
        )

        for chunk in completion:
            if chunk.choices[0].delta.content is not None:
                print(chunk.choices[0].delta.content, end="", flush=True)
        print()
    except Exception as e:
        report_error(e)
        print(f"\nError: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
