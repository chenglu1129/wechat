package api

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// 媒体类型
type MediaType string

const (
	MediaTypeImage MediaType = "image"
	MediaTypeAudio MediaType = "audio"
	MediaTypeVideo MediaType = "video"
	MediaTypeFile  MediaType = "file"
)

// 媒体上传响应
type MediaUploadResponse struct {
	Success bool   `json:"success"`
	URL     string `json:"url"`
	Type    string `json:"type"`
	Name    string `json:"name"`
	Size    int64  `json:"size"`
}

// 媒体上传处理程序
// @Summary 上传媒体文件
// @Description 上传图片、音频、视频或文件
// @Tags media
// @Accept multipart/form-data
// @Produce json
// @Param file formData file true "要上传的文件"
// @Param type formData string false "媒体类型 (image, audio, video, file)"
// @Success 200 {object} MediaUploadResponse
// @Failure 400 {object} APIResponse
// @Failure 401 {object} APIResponse
// @Failure 500 {object} APIResponse
// @Router /api/media/upload [post]
func (a *API) UploadMedia(w http.ResponseWriter, r *http.Request) {
	// 获取当前用户ID
	userID, err := a.GetUserIDFromContext(r.Context())
	if err != nil {
		RespondWithError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// 解析多部分表单数据，最大10MB
	err = r.ParseMultipartForm(10 << 20) // 10MB
	if err != nil {
		RespondWithError(w, http.StatusBadRequest, "无法解析表单数据")
		return
	}

	// 获取文件
	file, handler, err := r.FormFile("file")
	if err != nil {
		RespondWithError(w, http.StatusBadRequest, "无法获取上传的文件")
		return
	}
	defer file.Close()

	// 检查文件大小
	if handler.Size > 10<<20 { // 10MB
		RespondWithError(w, http.StatusBadRequest, "文件太大，最大允许10MB")
		return
	}

	// 检查文件类型
	contentType := handler.Header.Get("Content-Type")
	mediaType := MediaType(r.FormValue("type"))

	// 如果未指定媒体类型，根据Content-Type猜测
	if mediaType == "" {
		mediaType = guessMediaType(contentType)
	}

	// 验证媒体类型
	if !isValidMediaType(mediaType) {
		RespondWithError(w, http.StatusBadRequest, "无效的媒体类型")
		return
	}

	// 创建保存文件的目录
	uploadDir := filepath.Join("uploads", string(mediaType), fmt.Sprintf("user_%d", userID))
	err = os.MkdirAll(uploadDir, 0755)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "无法创建上传目录")
		return
	}

	// 生成唯一文件名
	fileExt := filepath.Ext(handler.Filename)
	if fileExt == "" {
		fileExt = guessFileExtension(contentType)
	}

	fileName := fmt.Sprintf("%s_%s%s",
		time.Now().Format("20060102150405"),
		uuid.New().String()[0:8],
		fileExt,
	)

	filePath := filepath.Join(uploadDir, fileName)

	// 保存文件
	dst, err := os.Create(filePath)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "无法创建文件")
		return
	}
	defer dst.Close()

	_, err = io.Copy(dst, file)
	if err != nil {
		RespondWithError(w, http.StatusInternalServerError, "无法保存文件")
		return
	}

	// 生成URL
	fileURL := fmt.Sprintf("/api/media/%s/%s", string(mediaType), fileName)

	// 返回响应
	response := MediaUploadResponse{
		Success: true,
		URL:     fileURL,
		Type:    string(mediaType),
		Name:    handler.Filename,
		Size:    handler.Size,
	}

	RespondWithJSON(w, http.StatusOK, response)
}

// 媒体获取处理程序
// @Summary 获取媒体文件
// @Description 获取上传的媒体文件
// @Tags media
// @Produce octet-stream
// @Param type path string true "媒体类型 (image, audio, video, file)"
// @Param filename path string true "文件名"
// @Success 200 {file} byte
// @Failure 404 {object} APIResponse
// @Router /api/media/{type}/{filename} [get]
func (a *API) GetMedia(w http.ResponseWriter, r *http.Request) {
	// 获取路径参数
	vars := mux.Vars(r)
	mediaType := vars["type"]
	fileName := vars["filename"]

	// 验证媒体类型
	if !isValidMediaType(MediaType(mediaType)) {
		RespondWithError(w, http.StatusBadRequest, "无效的媒体类型")
		return
	}

	// 检查文件名是否包含路径分隔符（防止目录遍历攻击）
	if strings.Contains(fileName, "/") || strings.Contains(fileName, "\\") {
		RespondWithError(w, http.StatusBadRequest, "无效的文件名")
		return
	}

	// 构建文件路径
	filePath := filepath.Join("uploads", mediaType, fileName)

	// 检查文件是否存在
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		RespondWithError(w, http.StatusNotFound, "文件不存在")
		return
	}

	// 设置适当的Content-Type
	contentType := getContentTypeFromFileName(fileName)
	w.Header().Set("Content-Type", contentType)
	w.Header().Set("Cache-Control", "max-age=31536000") // 1年缓存

	// 发送文件
	http.ServeFile(w, r, filePath)
}

// 根据Content-Type猜测媒体类型
func guessMediaType(contentType string) MediaType {
	contentType = strings.ToLower(contentType)

	if strings.HasPrefix(contentType, "image/") {
		return MediaTypeImage
	} else if strings.HasPrefix(contentType, "audio/") {
		return MediaTypeAudio
	} else if strings.HasPrefix(contentType, "video/") {
		return MediaTypeVideo
	} else {
		return MediaTypeFile
	}
}

// 验证媒体类型是否有效
func isValidMediaType(mediaType MediaType) bool {
	switch mediaType {
	case MediaTypeImage, MediaTypeAudio, MediaTypeVideo, MediaTypeFile:
		return true
	default:
		return false
	}
}

// 根据Content-Type猜测文件扩展名
func guessFileExtension(contentType string) string {
	contentType = strings.ToLower(contentType)

	switch contentType {
	case "image/jpeg", "image/jpg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/gif":
		return ".gif"
	case "audio/mpeg":
		return ".mp3"
	case "audio/wav":
		return ".wav"
	case "video/mp4":
		return ".mp4"
	case "application/pdf":
		return ".pdf"
	case "application/msword":
		return ".doc"
	case "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
		return ".docx"
	default:
		return ""
	}
}

// 根据文件名获取Content-Type
func getContentTypeFromFileName(fileName string) string {
	ext := strings.ToLower(filepath.Ext(fileName))

	switch ext {
	case ".jpg", ".jpeg":
		return "image/jpeg"
	case ".png":
		return "image/png"
	case ".gif":
		return "image/gif"
	case ".mp3":
		return "audio/mpeg"
	case ".wav":
		return "audio/wav"
	case ".mp4":
		return "video/mp4"
	case ".pdf":
		return "application/pdf"
	case ".doc":
		return "application/msword"
	case ".docx":
		return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
	default:
		return "application/octet-stream"
	}
}
