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

    print(current_dir)
    print(file_name)
    package = file_name.split("/")[1]
    print(package)

    # Ensure image_name has a valid tag or digest
    if ":" not in image_name and "@" not in image_name:
        image_name += ":latest"

    print(f"Using Docker image: {image_name}")

    container = None
    result = None
    try:
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
            stderr=True,
        )
        result = container.wait()
    except Exception as e:
        print(f"Failed to create/run container: {e}")
        return  # Exit early to avoid using uninitialized container

    try:
        if container:
            print(container.logs().decode("utf-8"))
    except Exception:
        print(container.logs() if container else "No logs available")

    if container:
        container.remove()

    if result and int(result["StatusCode"]) != 0:
        raise Exception(f"Build script validation failed for {file_name} !")
    else:
        return True

if __name__ == "__main__":
    print("Inside python program")
    trigger_script_validation_checks(sys.argv[1], sys.argv[2], sys.argv[3])
