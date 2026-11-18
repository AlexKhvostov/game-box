import {awardFanfare} from './award-artwork.ts';

const gestures = ['pointerup', 'click', 'keydown'] as const;

/** Owns a single award cue, including a deferred cue started by a dismiss button. */
export class AwardFanfare {
  private audio: HTMLAudioElement | undefined;
  private open = false;
  private waiting = false;
  private finishAfterClose = false;
  private volume = 0;
  private closesAward: ((event: Event) => boolean) | undefined;

  prepare(muted: boolean, volume: number, closesAward: (event: Event) => boolean) {
    this.stop();
    this.open = true;
    this.closesAward = closesAward;
    this.configure(muted, volume);
    if (!this.volume) return;
    this.waiting = true;
    for (const type of gestures) window.addEventListener(type, this.onGesture, true);
  }

  configure(muted: boolean, volume: number) {
    this.volume = muted || !Number.isFinite(volume) ? 0 : Math.max(0, Math.min(0.25, volume));
    if (!this.volume) {
      this.stop();
    } else if (this.audio) {
      this.audio.volume = this.volume;
    }
  }

  present() {
    if (navigator.userActivation?.hasBeenActive !== false) this.play();
  }

  close() {
    this.open = false;
    this.waiting = false;
    this.removeGestures();
    // The first tap can both unlock a deferred cue and press Continue.
    if (!this.finishAfterClose) this.releaseAudio();
  }

  stop() {
    this.finishAfterClose = false;
    this.close();
  }

  private onGesture = (event: Event) => {
    if (!event.isTrusted) return;
    if (event instanceof KeyboardEvent &&
      (event.key === 'Escape' || event.ctrlKey || event.altKey || event.metaKey)) return;
    this.play(this.closesAward?.(event) ?? false);
  };

  private play(finishAfterClose = false) {
    if (!this.open || !this.waiting || !this.volume || document.hidden) return;
    this.waiting = false;
    this.finishAfterClose = finishAfterClose;
    const audio = this.audio = new Audio(awardFanfare);
    audio.volume = this.volume;
    audio.addEventListener('ended', () => {
      if (audio === this.audio) this.releaseAudio();
    }, {once: true});
    // Invoke play in the input handler itself. A later timer can lose activation.
    void audio.play().then(() => {
      if (audio === this.audio) this.removeGestures();
    }, error => {
      if (audio !== this.audio) return;
      this.releaseAudio();
      this.waiting = this.open && error?.name === 'NotAllowedError';
      if (!this.waiting) this.removeGestures();
    });
  }

  private removeGestures() {
    for (const type of gestures) window.removeEventListener(type, this.onGesture, true);
  }

  private releaseAudio() {
    const audio = this.audio;
    this.audio = undefined;
    if (!audio) return;
    audio.pause();
    audio.removeAttribute('src');
    audio.load();
  }
}
