using UnityEngine;

public class KinectDepthTextureViewer : MonoBehaviour
{
    [SerializeField]
    KinectDepthSourceManager depthSourceManager;

    void Start()
    {
        GetComponent<Renderer>().material.mainTexture = depthSourceManager.GetDepthTexture();
    }
}
