import os
import stat
import sys
import docker

def trigger_script_validation_checks(file_name, version, image_name):
    # Ensure Docker image has a proper tag
    if ":" not in image_name and "@" not in image_name:
        image_name += ":latest"  # Add default tag if none provided

    client = docker.DockerClient(base_url='unix://var/run/docker.sock')
    st = os.stat(file_name)
    current_dir = os.getcwd()
    os.chmod("{}/{}".format(current_dir, file_name), st.st_mode | stat.S_IEXEC)

    print(current_dir)
    print(file_name)
    package = file_name.split("/")[1]  # Assuming file path is in format w/pkg/script.sh
    print(package)

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
            volumes={
                current_dir: {'bind': '/home/tester/', 'mode': 'rw'}
            },
            stderr=True,
        )
        result = container.wait()
    except Exception as e:
        print(f"Failed to create/run container: {e}")
        raise

    try:
        print(container.logs().decode("utf-8"))
    except Exception:
        print(container.logs())

    container.remove()

    if int(result["StatusCode"]) != 0:
        raise Exception(f"Build script validation failed for {file_name}!")
    else:
        return True

if __name__ == "__main__":
    print("Inside python program")
    trigger_script_validation_checks(sys.argv[1], sys.argv[2], sys.argv[3])
