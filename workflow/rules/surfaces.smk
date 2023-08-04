
rule fastsurfer_seg:
    input: rules.get_template_t1.output
    output:
        directory(
            sourcedata / "fastsurfer" / Path(bids(**inputs.subj_wildcards)).name
        )
    benchmark: out/f"code/benchmark/fastsurfer/{uid}.tsv"
    log: out/f"code/log/fastsurfer/{uid}.log"
    container: config["containers"]["fastsurfer"]
    resources:
        gpu=1,
        runtime=3,
        mem_mb=10000,
    params:
        fs_license=config["fs_license"],
        sid=lambda wcards, output: Path(output[0]).name,
        sd=lambda wcards, output: Path(output[0]).parent,
    threads: 1
    group: 'fastsurfer_seg'
    shell:
        """
        /fastsurfer/run_fastsurfer.sh --fs_license {params.fs_license} \\
            --t1 {input} --sid {params.sid} --sd {params.sd} \\
            --seg_only &> {log}
        """

rule fastsurfer_surf:
    input:
        t1=rules.get_template_t1.output,
        seg=rules.fastsurfer_seg.output,
    output:
        directory(
            sourcedata / "fastsurfer_surf" / Path(bids(**inputs.subj_wildcards)).name
        )
    benchmark: out/f"code/benchmark/fastsurfer_surf/{uid}.tsv"
    log: out/f"code/log/fastsurfer_surf/{uid}.log"
    container: config["containers"]["fastsurfer"]
    resources:
        runtime=150,
        mem_mb=10000,
    params:
        fs_license=config["fs_license"],
        sid=lambda wcards, output: Path(output[0]).name,
        sd=lambda wcards, output: Path(output[0]).parent,
    threads: 4
    group: 'fastsurfer_surf'
    shell:
        """
        src="{input.seg}"
        length=$(printf '%s' "$src" | wc -m)
        for f in $(find "$src" -type f -o -type l); do
            rel="${{f:length}}"
            dest="{output}/$rel"
            dir=$(dirname "$dest")
            mkdir -p "$dir"
            ln -s "$(realpath --relative-to "$dir" "$src/$rel")" "$dest"
        done
        /fastsurfer/run_fastsurfer.sh --fs_license {params.fs_license} \\
            --t1 {input.t1} --sid {params.sid} --sd {params.sd} \\
            --surf_only --threads {threads} &> {log}
        """

rule ciftify:
    input:
        rules.fastsurfer_surf.output[0],
    output:
        directory(
            sourcedata / "ciftify" / Path(bids(**inputs.subj_wildcards)).name
        )
    benchmark: out/f"code/benchmark/ciftify/{uid}.tsv"
    log: out/f"code/log/ciftify/{uid}.log"
    # container: config["containers"]["ciftify"]
    resources:
        runtime=240,
        mem_mb=10000,
    threads: 4
    params:
        sid=lambda wcards, output: Path(output[0]).name,
        sd=lambda wcards, output: Path(output[0]).parent,
        fs_dir=lambda wcards, input: Path(input[0]).parent,
        fs_license=config["fs_license"],
    group: 'ciftify'
    shell:
        """
        singularity exec /project/6050199/knavynde/containers/uris/docker/tigrlab/fmriprep_ciftify/v1.3.2-2.3.3.sif \\
        ciftify_recon_all {params.sid} \\
            --ciftify-work-dir {params.sd} --fs-subjects-dir {params.fs_dir}  \\
            --fs-license {params.fs_license} --n_cpus {threads} --resample-to-T1w32k \\
            --debug &> {log}
            
        """


rule bidsify:
    input: 
        data=rules.ciftify.output,
        config=workflow.source_path('../../resources/from-ciftify_to-bids.yaml')
    output:
        flag=touch(
            sourcedata / "bidsify" / Path(bids(**inputs.subj_wildcards)).name
        ),
        invwarp=bids(
            out,
            datatype="xfm",
            mode="image",
            from_="MNI152NLin6Asym",
            to="T1w",
            suffix="xfm.nii.gz",
            **inputs.subj_wildcards,
        ),
        warp=bids(
            out,
            datatype="xfm",
            mode="image",
            to="MNI152NLin6Asym",
            from_="T1w",
            suffix="xfm.nii.gz",
            **inputs.subj_wildcards,
        ),
        affine=bids(
            out,
            datatype="xfm",
            mode="image",
            from_="T1w",
            to="MNI152NLin6Asym",
            suffix="xfm.mat",
            **inputs.subj_wildcards,
        ),
        mni_ref=bids(
            out,
            datatype="anat",
            space="MNI152NLin6ASym",
            desc="preproc",
            suffix="T1w.nii.gz",
            **inputs.subj_wildcards,
        ),
        t1w_ref=bids(
            out,
            datatype="anat",
            space="T1w",
            desc="preproc",
            suffix="T1w.nii.gz",
            **inputs.subj_wildcards,
        ),
    params:
        entities=lambda wcards: " ".join([
            "--bids " + "=".join(pair)
            for pair in inputs.subj_wildcards.items()
        ]).format(**wcards)
    envmodules:
        'python/3.10'
    shell:
        boost(
            pathxf_venv.script,
            "pathxf {input.config} -i {input.data} "
            "{params.entities}",
        )