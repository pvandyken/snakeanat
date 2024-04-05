"""Rules to convert the FSL transforms output by cifitify into ITK h5 files
"""

rule convert_transforms_to_itk:
    input:
        warp=rules.bidsify.output["warp"],
        invwarp=rules.bidsify.output["invwarp"],
        affine=rules.bidsify.output["affine"],
        mni_ref=rules.bidsify.output["mni_ref"],
        t1w_ref=rules.bidsify.output["t1w_ref"],
    output:
        warp=temp(work/"convert_transforms_to_itk"/uid/"warp.nii.gz"),
        invwarp=temp(work/"convert_transforms_to_itk"/uid/"invwarp.nii.gz"),
        affine=temp(work/"convert_transforms_to_itk"/uid/"affine.txt"),
    container:
        config["containers"]["autotop"]
    resources:
        runtime=10,
        mem_mb=5000,
    group: "finish"
    shell:
        """
        wb_command -convert-affine \\
            -from-flirt {input.affine} {input.t1w_ref} {input.mni_ref} \\
            -to-itk {output.affine}
        wb_command -convert-warpfield \\
            -from-fnirt {input.warp} {input.mni_ref} \\
            -to-itk {output.warp}
        wb_command -convert-warpfield \\
            -from-fnirt {input.invwarp} {input.mni_ref} \\
            -to-itk {output.invwarp}
        """

rule convert_transforms_to_h5:
    input:
        warp=rules.convert_transforms_to_itk.output["warp"],
        invwarp=rules.convert_transforms_to_itk.output["invwarp"],
        affine=rules.convert_transforms_to_itk.output["affine"],
    output:
        forward=bids(
            out,
            datatype="xfm",
            from_="T1w",
            to="MNI152NLin6ASym",
            mode="image",
            suffix="xfm.h5",
            **inputs.subj_wildcards,
        ),
        inverse=bids(
            out,
            datatype="xfm",
            from_="MNI152NLin6ASym",
            to="T1w",
            mode="image",
            suffix="xfm.h5",
            **inputs.subj_wildcards,
        ),
    envmodules:
        'python/3.10'
    group: "finish"
    resources:
        runtime=1,
        mem_mb=500,
    shell:
        boost(
            simpleitk_env.script,
            pyscript(
                "scripts/merge_transforms.py",
                input=["warp", "invwarp", "affine"],
                output=["forward", "inverse"],
            )
        )

