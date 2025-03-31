### General instructions: 
- Get started within MicroShift and image-mode (bootc) first https://docs.redhat.com/en/documentation/red_hat_build_of_microshift/4.18/html-single/installing_with_rhel_image_mode/index
- Then, embeed MicroShift and Application Container Images for offline deployments based on this:
  -  PR https://github.com/openshift/microshift/pull/4739 
  - https://github.com/ggiguash/microshift/blob/bootc-embedded-image-upgrade-418/docs/contributor/image_mode.md#appendix-b-embedding-container-images-in-bootc-builds 
  - https://gitlab.com/fedora/bootc/examples/-/tree/main/physically-bound-images

#### Step by step 
- Build the first image with `bash -x build.sh v1`
  - That will include the MicroShift payload + an sample wordpress Container image to the bootc image
  - Also produces a ISO image, to be used to install RHDE. 
- Build the second image with `bash -x build.sh v2`
  - That will include RHEL updates + a sample mysql Container image to bootc image tagged as V2.
  - Also produces a ISO image
