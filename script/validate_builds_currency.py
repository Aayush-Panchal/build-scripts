import os
import stat
import requests
import sys
import subprocess
import docker
import json
        
def trigger_script_validation_checks(file_name, version, image_name):
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    st = os.stat(file_name)
    current_dir = os.getcwd()
    os.chmod(f"{current_dir}/{file_name}", st.st_mode | stat.S_IEXEC)

    print(f"[INFO] Current dir: {current_dir}")
    print(f"[INFO] Build script: {file_name}")
    print(f"[INFO] Version: {version}")
    print(f"[INFO] Raw image name: {image_name}")

    package = file_name.split("/")[1]
    print(f"[INFO] Package: {package}")

    # --- Fix: ensure valid docker reference (repo:tag) ---
    if " " in image_name:  
        parts = image_name.split()
        if len(parts) == 2:
            image_name = f"{parts[0]}:{parts[1]}"
            print(f"[FIX] Corrected image name to: {image_name}")

    container = None
    result = {"StatusCode": 1}

    try:
        command = [
            "bash",
            "-c",
            f"cd /home/tester/ && ./{file_name} {version}"
        ]

        container = client.containers.run(
            image_name,
            command,
            network='host',
            detach=True,
            volumes={current_dir: {'bind': '/home/tester/', 'mode': 'rw'}},
            stderr=True,
        )
        result = container.wait()
    except Exception as e:
        print(f"[ERROR] Failed to create container: {e}")

    if container:
        try:
            logs = container.logs()
            try:
                print(logs.decode("utf-8"))
            except Exception:
                print(logs)
        finally:
            container.remove()

    if int(result.get("StatusCode", 1)) != 0:
        raise Exception(f"Build script validation failed for {file_name}!")
    else:
        return True


if __name__ == "__main__":
    print("Inside python program")
    trigger_script_validation_checks(sys.argv[1], sys.argv[2], sys.argv[3])
