
uid_no_echo = Path(bids(**inputs["t1w"].wildcards)).name

def drop_entity(zip_list, entity):
    new = {k: v for k, v in zip_list.items() if k != entity}
    return dict(zip(new.keys(), zip(*set(zip(*new.values())))))

def merge_zip_list(__d1, __d2):
    new = copy.copy(__d1)
    for k, v in __d2.items():
        new[k].extend(v)
    return new

def _get_echos(wcards):
    if "t1w_echo" in inputs:
        echo_wcards = filter_list(inputs["t1w_echo"].zip_lists, wcards)
    else:
        echo_wcards = None
    if echo_wcards and next(iter(echo_wcards.values())):
        return expand(
            inputs["t1w_echo"].path,
            zip,
            **echo_wcards
        )
    return inputs["t1w"].path

rule average_echos:
    input: _get_echos
    output: temp(work/"average_echos"/uid_no_echo/"T1w.nii.gz")
    container:
        config["containers"]["autotop"]
    group: 'fastsurfer_seg'
    shell:
        """
        INPUTS="{input}"
        if [[ $(echo "$INPUTS" | wc -w) -gt 1 ]]; then
            c3d $INPUTS -mean -o {output}
        else
            cp $INPUTS {output}
        fi
        """


def get_ref_t1(wildcards):
    echo = inputs["t1w_echo"].zip_lists if "t1w_echo" in inputs else {}
    filtered = merge_zip_list(
        filter_list(inputs["t1w"].zip_lists, wildcards),
        filter_list(drop_entity(echo, "echo"), wildcards),
    )
    # get the first image
    return expand(
        rules.average_echos.output,
        zip,
        **filtered
    )[0]


def _get_floating_t1(wildcards):
    echo = inputs["t1w_echo"].zip_lists if "t1w_echo" in inputs else {}
    filtered = merge_zip_list(
        filter_list(inputs["t1w"].zip_lists, wildcards),
        filter_list(drop_entity(echo, "echo"), wildcards),
    )
    imgs = expand(
        rules.average_echos.output,
        zip,
        **filtered
    )
    return imgs[int(wildcards.idx)]

rule reg_t1_to_ref:
    input:
        ref=get_ref_t1,
        flo=_get_floating_t1,
    output:
        xfm_ras=temp(work/"reg_t1_to_ref"/uid/"{idx}_ras.txt"),
        xfm_itk=temp(work/"reg_t1_to_ref"/uid/"{idx}_itk.txt"),
        warped=temp(work/"reg_t1_to_ref"/uid/"{idx}_warped.nii.gz"),
    container:
        config["containers"]["autotop"]
    resources:
        runtime=10,
        mem_mb=5000,
    group: 'fastsurfer_seg'
    shell:
        """
        reg_aladin -flo {input.flo} -ref {input.ref} -res {output.warped} \\
            -aff {output.xfm_ras} -rigOnly -nac
        c3d_affine_tool  {output.xfm_ras} -oitk {output.xfm_itk}
        """

def _get_aligned_t1s(wildcards):
    echo = inputs["t1w_echo"].zip_lists if "t1w_echo" in inputs else {}
    # first get the number of floating t2s
    filtered = merge_zip_list(
        filter_list(inputs["t1w"].zip_lists, wildcards),
        filter_list(drop_entity(echo, "echo"), wildcards),
    )
    num_scans = len(filtered["subject"])

    # then, return the path, expanding over range(1,num_scans) -i.e excludes 0 (ref image)
    return expand(
        rules.reg_t1_to_ref.output.warped,
        idx=range(1, num_scans),
        **wildcards,
    )

rule get_template_t1:
    input:
        ref=get_ref_t1,
        flo=_get_aligned_t1s,
    output:
        temp(
            bids(
                root=out,
                datatype="anat",
                suffix="T1w.nii.gz",
                desc="template",
                **inputs.subj_wildcards,
            )
        ),
    container:
        config["containers"]["autotop"]
    group: 'fastsurfer_seg'
    shell:
        """
        INPUTS="{input}"
        if [[ $(echo "$INPUTS" | wc -w) -gt 1 ]]; then
            c3d $INPUTS -mean -o {output}
        else
            cp $INPUTS {output}
        fi
        """