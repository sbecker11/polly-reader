import argparse
from pathlib import Path

import boto3
import os
import time
import subprocess
import platform

MAX_TEXT_LENGTH = 10000
MIN_TEXT_LENGTH = 100

def is_valid_file(file_path: str) -> bool:
    try:
        if file_path is None:
            raise ValueError(f"File_path is None")
        path = Path(file_path)
        if not path.exists():
            raise FileNotFoundError(f"File does not exist: {file_path}")
        if not path.is_file():
            raise RuntimeError(f"File is not a file: {file_path}")
        return True
    except Exception as e:
        print(f"Error {e} validating file: {file_path}")
        return False

def is_valid_text_file(text_file: str) -> bool:
    try:
        if not is_valid_file(text_file):
            raise ValueError(f"Text file is not a valid file: {text_file}")
        if not text_file.endswith(".txt"):
            raise ValueError(f"Text file must end with .txt: {text_file}")
        return True
    except Exception as e:
        print(f"Error {e} validating text file: {text_file}")
        return False

def is_valid_mp3_file(mp3_file_path: str) -> bool:
    try:
        if not is_valid_file(mp3_file_path):
            raise ValueError(f"mp3_file_path is not a valid file path: {mp3_file_path}")
        if not mp3_file_path.endswith(".mp3"):
            raise ValueError(f"mp3_file_path must end with .mp3: {mp3_file_path}")
        return True
    except Exception as e:
        print(f"Error {e} validating mp3_file_path: {mp3_file_path}")
        return False

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Start an Amazon Polly speech synthesis task from a text file."
    )
    parser.add_argument("textfile", help="Path to a UTF-8 text file to synthesize.")
    parser.add_argument(
        "--bucket",
        default="sbecker11-poly-test",
        help="S3 bucket where Polly writes the audio output (default: sbecker11-poly-test).",
    )
    parser.add_argument(
        "--prefix",
        default="polly-output",
        help="S3 key prefix for output files (default: polly-output).",
    )
    parser.add_argument(
        "--region",
        default="us-east-1",
        help="AWS region for Polly (default: us-east-1).",
    )
    parser.add_argument(
        "--voice-id",
        default="Matthew",
        help="Polly voice ID (default: Matthew).",
    )
    parser.add_argument(
        "--engine",
        default="neural",
        choices=["standard", "neural", "long-form", "generative"],
        help="Polly synthesis engine (default: neural).",
    )
    parser.add_argument(
        "--output-format",
        default="mp3",
        choices=["mp3", "ogg_vorbis", "pcm", "json"],
        help="Output format (default: mp3).",
    )
    parser.add_argument(
        "--output-file",
        default="output.mp3",
        help="Local filename to save the downloaded MP3 to (default: output.mp3).",
    )

    return parser


def main() -> None:
    args = build_parser().parse_args()

    region = args.region
    if region is None:
        raise ValueError(f"Region is required")
    if region not in ["us-east-1", "us-east-2", "us-west-1", "us-west-2", "eu-west-1", "eu-central-1", "ap-northeast-1", "ap-northeast-2", "ap-southeast-1", "ap-southeast-2", "ap-south-1", "ca-central-1", "cn-north-1", "cn-northwest-1", "eu-north-1", "sa-east-1"]:
        raise ValueError(f"Invalid region: {region}")

    output_file = args.output_file
    if output_file is None:
        raise ValueError(f"Output file is required")
    

    textfile = args.textfile
    if not is_valid_text_file(textfile):
        raise ValueError(f"textfile is not valid: {textfile}")

    path = Path(textfile)
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise ValueError(f"Text file is empty: {textfile}")
    if len(text) < MIN_TEXT_LENGTH:
        raise ValueError(f"Text file is too short: {textfile}")
    if len(text) > MAX_TEXT_LENGTH:
        raise ValueError(f"Text file is too long: {textfile}")

    polly_client = boto3.client("polly", region_name=args.region)

    response = polly_client.start_speech_synthesis_task(
        VoiceId=args.voice_id,
        OutputS3BucketName=args.bucket,
        OutputS3KeyPrefix=args.prefix,
        OutputFormat=args.output_format,
        Text=text,
        Engine=args.engine,
    )

    task_id = response["SynthesisTask"]["TaskId"]
    print(f"Task id is {task_id}")

    output_uri = None
    while True:
        status_resp = polly_client.get_speech_synthesis_task(TaskId=task_id)
        task = status_resp["SynthesisTask"]
        if task["TaskStatus"] == "completed":
            output_uri = task["OutputUri"]
            break
        if task["TaskStatus"] in ("failed", "cancelled"):
            raise RuntimeError(task.get("TaskStatusReason", "Polly task failed"))
        time.sleep(2)

    # gather boto3 arguments from the output URI
    if output_uri is None:
        raise RuntimeError("Output URI is None")
   
    s3 = boto3.client("s3", region_name=args.region)
    if s3 is None:
        raise RuntimeError("S3 client is None")

    bucket_name = output_uri.split("/")[3] 
    object_key = "/".join(output_uri.split("/")[4:]) 
   
    s3.download_file(bucket_name, object_key, output_file)
    print(f"{output_file} downloaded successfully")

    if not is_valid_file(output_file):
        raise RuntimeError(f"{output_file} is not a valid file")

    if not is_valid_mp3_file(output_file):
        raise RuntimeError(f"{output_file} is not a valid mp3 file")

    # get the system
    system = platform.system()
    if system is None:
        raise RuntimeError(f"system is None")
    if system not in ["Darwin", "Windows", "Linux"]:
        raise RuntimeError(f"Invalid system: {system}")

    # automatically play the audio file 
    if system == "Darwin":
        print(f"starting to play {output_file} with afplay on macOS")
        subprocess.run(["afplay", output_file], check=True)
        print(f"{output_file} played successfully on macOS")
    elif system == "Windows":
        subprocess.run(f'start "" "{output_file}"', shell=True, check=True)
        print(f"{output_file} started successfully on Windows")
    elif system == "Linux":
        subprocess.run(["xdg-open", output_file], check=True)
        print(f"{output_file} launched successfully with xdg-open on Linux")
    else:
        raise RuntimeError(f"Unsupported system: {system}")

if __name__ == "__main__":
    main()
