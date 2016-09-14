- hosts: all
  vars:
    - source_dir: /home/cs02gl/programs/.source
    - software_dir: /home/cs02gl/programs

  pre_tasks:
    - name: Create Software Dir
      file: path={{software_dir}} state=directory
    - name: Create Software Source Dir
      file: path={{source_dir}} state=directory

  tasks:
    # SNAP and Perl_libs
    - include: tasks/snap.yaml version=2013-11-29
      tags: snap
    - include: tasks/ik_perl.yaml
      tags: perl


    # GENEMARK
    - include: tasks/genemark.yaml
      tags: genemark


    ## MAKER

    # REPEATMASKER
    #- include: tasks/rmblast.yaml
    #  tags: repeatmasker, rmblast, maker

    - include: tasks/repeatmasker.yaml
      tags: repeatmasker, maker

    # HMMER
    - include: tasks/hmmer.yaml version=3.1b2
      tags: hmmer, maker

    # MAKER
    - include: tasks/maker.yaml
      tags: maker
