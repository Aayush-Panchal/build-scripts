import os
import stat
import requests
import sys
import subprocess
import docker
import json

def trigger_script_validation_checks(file_name, version, image_name):
    # Spawn a container and pass the build script
    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    st = os.stat(file_name)
    current_dir = os.getcwd()
    os.chmod("{}/{}".format(current_dir, file_name), st.st_mode | stat.S_IEXEC)
    # Let the container run in non-detach mode, as we need to delete the container on operation completion
    print(current_dir)
    print(file_name)
    package = file_name.split("/")[1]
    print(package)

    container = None
    result = {"StatusCode": 1}

    try:
        # Validate image format
        if not image_name or ":" not in image_name:
            raise ValueError(f"Invalid Docker image reference: '{image_name}'")

        command = [
            "bash",
            "-c",
            f"cd /home/tester/ && ./{file_name} {version} "
        ]

        container = client.containers.run(
            image_name,
            command,
            network='host',
            detach=True,
            volumes={
                current_dir: {'bind': '/home/tester/', 'mode': 'rw'}
            },
            stderr=True,  # Return logs from STDERR
        )
        result = container.wait()
    except Exception as e:
        print(f"Failed to create/run container: {e}")

    try:
        if container:
            print(container.logs().decode("utf-8"))
    except Exception as e:
        print(f"Error fetching logs: {e}")
        if container:
            try:
                print(container.logs())
            except Exception:
                print("[WARN] Could not fetch logs at all.")

    if container:
        try:
            container.remove()
        except Exception as e:
            print(f"Error removing container: {e}")

    if int(result["StatusCode"]) != 0:
        raise Exception(f"Build script validation failed for {file_name} !")
    else:
        return True

if __name__ == "__main__":
    print("Inside python program")
    trigger_script_validation_checks(sys.argv[1], sys.argv[2], sys.argv[3])
