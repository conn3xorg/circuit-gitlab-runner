# Local example

Applies circuit-gitlab-runner to a throwaway Ubuntu 24.04 container with systemd, with the shell executor. You need Conn3x and Podman, and for the runner to take jobs, a GitLab it can reach and a runner authentication token from it. See [Usage](../../README.md#usage) for creating one.

```sh
export TF_VAR_gitlab_url='http://192.168.1.30'
export TF_VAR_runner_token='glrt-...'
./up.sh
conn3x init
conn3x apply
conn3x plan
```

The second plan says `No changes.` Within a few seconds the runner shows as online on your runner's page in GitLab, with `box` as its manager. Push a commit with a `.gitlab-ci.yml` to a project it serves, and the job runs in the container as `gitlab-runner`.

Without a GitLab, any token starting `glrt-` will do to see what the circuit installs and writes. The runner then logs that it can't reach `gitlab.example.com`, which is all it can do:

```sh
ssh -p 2308 -i id_ed25519 -o UserKnownHostsFile=known_hosts root@127.0.0.1 gitlab-runner list
```

`up.sh` listens on `127.0.0.1:2308`. Set `PORT` to use another port, and pass the same port to Conn3x with `-var port=PORT`. Set `CONTAINERFILE` to test another distro, such as one of the images in Conn3x's `test/images`, which CI uses.

`./down.sh` removes the container, its volumes, the key and the state.
