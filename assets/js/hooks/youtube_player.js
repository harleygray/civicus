let YouTubePlayer = {
    mounted() {
        // Load YouTube IFrame Player API
        if (!window.YT) {
            const tag = document.createElement('script');
            tag.src = "https://www.youtube.com/iframe_api";
            const firstScriptTag = document.getElementsByTagName('script')[0];
            firstScriptTag.parentNode.insertBefore(tag, firstScriptTag);
        }

        // Initialize player when API is ready
        window.onYouTubeIframeAPIReady = () => {
            this.initPlayer();
        };

        // Handle seek events from LiveView
        this.handleEvent("seek_video", ({ time }) => {
            if (this.player) {
                this.player.seekTo(time);
                this.player.playVideo();
            }
        });
    },

    initPlayer() {
        const videoId = this.extractVideoId(this.el.dataset.embedUrl);

        this.player = new YT.Player('youtube-player', {
            videoId: videoId,
            playerVars: {
                enablejsapi: 1,
                origin: window.location.origin,
                rel: 0
            }
        });
    },

    extractVideoId(url) {
        const match = url.match(/embed\/([^?]+)/);
        return match ? match[1] : null;
    },

    destroyed() {
        if (this.player) {
            this.player.destroy();
        }
    }
}

export default YouTubePlayer; 