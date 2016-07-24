using UnityEngine;
using Windows.Kinect;

public class KinectDepthSourceManager : MonoBehaviour
{
    private KinectSensor sensor_;
    private DepthFrameReader depthReader_;
    private ushort[] data_;
    private byte[] rawData_;
    private CameraSpacePoint[] cameraSpacePoints_;

    private Texture2D texture_;
    public Texture2D GetDepthTexture()
    {
        return texture_;
    }

    public ushort[] GetData()
    {
        return data_;
    }

    void Awake()
    {
        sensor_ = KinectSensor.GetDefault();

        if (sensor_ != null) {
            depthReader_ = sensor_.DepthFrameSource.OpenReader();
            var frameDesc = sensor_.DepthFrameSource.FrameDescription;
            data_ = new ushort[frameDesc.LengthInPixels];
            rawData_ = new byte[frameDesc.LengthInPixels * 3];
            texture_ = new Texture2D(frameDesc.Width, frameDesc.Height, TextureFormat.RGB24, false);
            cameraSpacePoints_ = new CameraSpacePoint[frameDesc.Width * frameDesc.Height];

            if (!sensor_.IsOpen) {
                sensor_.Open();
            }
        }
    }

    void Update()
    {
        if (depthReader_ != null) {
            var frame = depthReader_.AcquireLatestFrame();
            if (frame != null) {
                frame.CopyFrameDataToArray(data_);
                sensor_.CoordinateMapper.MapDepthFrameToCameraSpace(data_, cameraSpacePoints_);

                for (int i = 0; i < data_.Length; ++i) {
                    var value = data_[i];
                    rawData_[3 * i + 0] = (byte)(value / 256);
                    rawData_[3 * i + 1] = (byte)(value % 256);
                    rawData_[3 * i + 2] = 0;
                }

                texture_.LoadRawTextureData(rawData_);
                texture_.Apply();

                frame.Dispose();
                frame = null;
            }
        }
    }

    void OnApplicationQuit()
    {
        if (depthReader_ != null) {
            depthReader_.Dispose();
            depthReader_ = null;
        }

        if (sensor_ != null) {
            if (sensor_.IsOpen) sensor_.Close();
            sensor_ = null;
        }
    }
}
