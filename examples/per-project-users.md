# One VM, one user per project

A personal alternative to one VM per project: a single long-lived VM with a
separate Linux user per project.

```bash
sudo useradd -m -s /bin/bash project-a
sudo chmod 700 /home/project-a
sudo install -d -o project-a -g project-a -m 700 /home/project-a/project
```

Switch projects by switching users:

```bash
sudo -iu project-a
cd ~/project
```

Easier for shared tool installs, but weaker than one VM per project: guest-root
compromise can read every project in the VM.
