
rule ciftify_vis:
    input:
        rules.ciftify.output[0],
        container=config["containers"]["ciftify_abspath"]
    output:
        directory(
            out / "qc" / Path(bids(**inputs.subj_wildcards)).name
        )
    benchmark: out/f"code/benchmark/ciftify_vis/{uid}.tsv"
    log: out/f"code/log/ciftify_vis/{uid}.log"
    resources:
        runtime=2,
        mem_mb=2000,
    threads: 1
    params:
        sid=lambda wcards, input: Path(input[0]).name,
        sd=lambda wcards, input: Path(input[0]).parent,
        qc_dir=lambda wcards, output: Path(output[0]).parent,
    group: 'ciftify'
    shell:
        """
        singularity exec {input.container} ciftify_recon_all {params.sid} \\
        cifti_vis_recon_all subject {params.sid} \\
            --qcdir {params.qc_dir} --ciftify-work-dir {params.sd} \\
            &> {log}
            
        """

rule ciftify_vis_group:
    input:
        inputs["t1w"].expand(rules.ciftify_vis.output),
    output:
        touch(sourcedata / "group_qc")
    benchmark: out/f"code/benchmark/ciftify_vis_group/log.tsv"
    log: out/f"code/log/ciftify_vis_group/log.log"
    container: config["containers"]["ciftify"]
    resources:
        runtime=2,
        mem_mb=2000,
    threads: 1
    params:
        sd=lambda wcards: Path(rules.ciftify.output[0]).parent,
        qc_dir=lambda wcards, input: Path(input[0]).parent,
    shell:
        """
        cifti_vis_recon_all index \\
            --qcdir {params.qc_dir} --ciftify-work-dir {params.sd} \\
            --debug &> {log}
            
        """
