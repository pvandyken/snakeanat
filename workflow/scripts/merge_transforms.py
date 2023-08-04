import SimpleITK as sitk
from snakeboost import snakemake_args


def main():
    snakemake = snakemake_args(
        input={
            "warp": "--warp",
            "invwarp": "--invwarp",
            "affine": "--affine",
        },
        output={
            "forward": "--out",
            "inverse": "--invout",
        },
    )

    warp_f = sitk.ReadImage(str(snakemake.input["warp"]), sitk.sitkVectorFloat64)
    warp_i = sitk.ReadImage(str(snakemake.input["invwarp"]), sitk.sitkVectorFloat64)
    affine = sitk.ReadTransform(str(snakemake.input["affine"]))
    warp = sitk.DisplacementFieldTransform(warp_f)
    warp.SetInverseDisplacementField(warp_i)
    composite = sitk.CompositeTransform([affine, warp])
    inv_composite = sitk.CompositeTransform([warp.GetInverse(), affine.GetInverse()])
    inv_composite.FlattenTransform()
    composite.FlattenTransform()
    inv_composite.WriteTransform(str(snakemake.output["inverse"]))
    composite.WriteTransform(str(snakemake.output["forward"]))

if __name__ == "__main__":
    main()