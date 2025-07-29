import os
import stat
import sys
import docker

def trigger_script_validation_checks(file_name, version, image_name):
    print("Inside trigger_script_validation_checks")

    # Show all inputs clearly
    print(f"Current working directory: {os.getcwd()}")
    print(f"Received file_name: '{file_name}'")
    print(f"Received version: '{version}'")
    print(f"Received image_name (raw): '{image_name}'")

    # Sanitize the image name (add :latest if no tag is given)
    if ":" not in image_name and "@" not in image_name:
        image_name = image_name.strip() + ":latest"
    else:
        image_name = image_name.strip()

    print(f"Sanitized image_name: '{image_name}'")

    current_dir = os.getcwd()
    file_path = os.path.join(current_dir, file_name)

    try:
        # Ensure script is executable
        st = os.stat(file_path)
        os.chmod(file_path, st.st_mode | stat.S_IEXEC)
    except Exception as e:
        print(f"Failed to set execute permission on {file_path}: {e}")
        raise

    try:
        command = [
            "bash",
            "-c",
            f"cd /home/tester/ && ./{file_name} {version}"
        ]
        print(f"Final Docker command: {command}")

        client = docker.DockerClient(base_url='unix://var/run/docker.sock')
        container = client.containers.run(
            image=image_name,
            command=command,
            network='host',
            detach=True,
            volumes={
                current_dir: {'bind': '/home/tester/', 'mode': 'rw'}
            },
            stderr=True
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

    if len(sys.argv) != 4:
        print("Usage: python3 validate_builds_currency.py <script_path> <version> <image_name>")
        sys.exit(1)

    file_name = sys.argv[1]
    version = sys.argv[2]
    image_name = sys.argv[3]

    trigger_script_validation_checks(file_name, version, image_name)
