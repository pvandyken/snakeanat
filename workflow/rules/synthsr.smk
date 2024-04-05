def with_suffix(path, suffix):
    path = Path(path)
    return path.parent / (path.name.split(".")[0] + suffix)

rule get_shells_from_bvals:
    input:
        bval=with_suffix(inputs["t1w"].path, ".bval")
    output:
        json=temp(work/f"get_shells_from_bvals/{uid}.shells.json"),
    group: 'fastsurfer_seg'
    container:
        config["containers"]["python"]
    script:
        "../scripts/get_shells_from_bvals.py"

rule get_avg_b0:
    input:
        dwi=inputs["t1w"].path,
        shells=rules.get_shells_from_bvals.output[0],
    output:
        avgshell=temp(work/f"get_b0/{uid}.nii.gz"),
    group: 'fastsurfer_seg'
    container:
        config["containers"]["python"]
    params:
        bval="0",
    resources:
        mem_mb=4000
    script:
        "../scripts/get_shell_avg.py"

rule run_synthSR:
    input:
        nii=rules.get_avg_b0.output
    output:
        out_nii=temp(work/f"run_synthsr/{uid}.nii.gz"),
    threads: 1
    group: 'fastsurfer_seg'
    log:
        bids(
            root="code/logs",
            suffix="run_synthSR.txt",
            **inputs["t1w"].wildcards,
        ),
    shadow:
        "minimal"
    resources:
        runtime=5,
        gpu=1,
    shell:
        """
        singularity exec --nv /project/6050199/knavynde/containers/uris/docker/akhanf/synthsr/main.sif \\
        python /SynthSR/scripts/predict_command_line.py {input} {output} &> {log}
        """


rule reslice_synthSR_b0:
    input:
        ref=rules.get_avg_b0.output,
        synthsr=rules.run_synthSR.output,
    output:
        synthsr=temp(bids(
            out,
            suffix="sT1w.nii.gz",
            datatype="anat",
            desc="snynthsr",
            **inputs["t1w"].wildcards,
        )),
    container:
        config["containers"]["itksnap"]
    group: 'fastsurfer_seg'
    shell:
        "c3d {input.ref} {input.synthsr} -reslice-identity -o {output.synthsr}"