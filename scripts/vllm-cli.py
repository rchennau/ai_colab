#!/usr/bin/env python3
import os
import sys
import argparse
from openai import OpenAI

def main():
    parser = argparse.ArgumentParser(description="Remote vLLM CLI Wrapper for Atari 800XL")
    parser.add_argument("-m", "--model", default="deepseek-ai/DeepSeek-Coder-V2-Lite-Instruct", help="Model name")
    parser.add_argument("-p", "--prompt", help="Prompt text")
    parser.add_argument("--system-prompt", help="System prompt")
    parser.add_argument("query", nargs="*", help="Positional query")

    args, unknown = parser.parse_known_args()

    # Remote vLLM server configuration
    base_url = os.environ.get("VLLM_BASE_URL", "http://192.168.0.193:8000/v1")
    api_key = os.environ.get("VLLM_API_KEY", "no-key")

    client = OpenAI(
        base_url=base_url,
        api_key=api_key
    )

    query_text = " ".join(args.query)
    if args.prompt:
        query_text = args.prompt + " " + query_text

    # Default Atari System Prompt if none provided
    system_prompt = args.system_prompt
    if not system_prompt:
        system_prompt = """You are an expert Atari 800XL software engineer. 
Your focus is on 6502 assembly language and Atari hardware registers (ANTIC, GTIA, POKEY).
You prioritize high-performance assembly routines, cycle counting, and efficient memory usage.

Atari 800XL Constraints:
- CPU: 6502 (1.79 MHz)
- RAM: 64KB
- OS Shadow Registers: RTCLOK ($12), SDLSTL ($230), SDMCTL ($22F)
- ANTIC DMACTL ($D400), CHBASE ($D409), WSYNC ($D40A)
- GTIA COLPF0-3 ($D016-D019), COLBK ($D01A)
- Assembler Preference: MADS or CA65 (default to MADS)

When asked to write code, provide well-commented 6502 assembly with memory address locations or standard labels."""

    if query_text.strip():
        # One-shot mode
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        messages.append({"role": "user", "content": query_text})
        
        try:
            completion = client.chat.completions.create(
                model=args.model,
                messages=messages,
                temperature=0.2,
                top_p=1,
                max_tokens=2048,
                stream=True
            )

            for chunk in completion:
                if chunk.choices and chunk.choices[0].delta.content is not None:
                    print(chunk.choices[0].delta.content, end="", flush=True)
            print()
        except Exception as e:
            print(f"\nError: {e}")
            sys.exit(1)
    else:
        # Interactive mode
        print(f"Connected to remote vLLM ({base_url})")
        print(f"Model: {args.model}")
        print("Type '/exit' or '/quit' to end session.")
        print("-" * 40)
        
        chat_history = []
        if system_prompt:
            chat_history.append({"role": "system", "content": system_prompt})
            
        while True:
            try:
                user_input = input("vLLM> ")
                if user_input.lower() in ["/exit", "/quit"]:
                    break
                if not user_input.strip():
                    continue
                    
                chat_history.append({"role": "user", "content": user_input})
                
                print("Thinking...", end="\r", flush=True)
                
                completion = client.chat.completions.create(
                    model=args.model,
                    messages=chat_history,
                    temperature=0.2,
                    top_p=1,
                    max_tokens=2048,
                    stream=True
                )

                print(" " * 12, end="\r", flush=True) # Clear "Thinking..."
                
                assistant_response = ""
                for chunk in completion:
                    if chunk.choices and chunk.choices[0].delta.content is not None:
                        content = chunk.choices[0].delta.content
                        print(content, end="", flush=True)
                        assistant_response += content
                print()
                chat_history.append({"role": "assistant", "content": assistant_response})
                
            except EOFError:
                break
            except KeyboardInterrupt:
                print("\nInterrupted.")
                continue
            except Exception as e:
                print(f"\nError: {e}")

if __name__ == "__main__":
    main()
