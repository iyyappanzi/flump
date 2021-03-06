//
// Flump - Copyright 2013 Flump Authors

package flump.test {

import flash.events.TimerEvent;
import flash.utils.Timer;

import executor.VisibleFuture;

import flump.display.Movie;
import flump.display.StarlingResources;

import com.threerings.util.F;

public class RuntimePlaybackTest
{
    public static function addTests (runner :TestRunner, res :StarlingResources) :void {
        runner.run("Goto frame and label", new RuntimePlaybackTest(runner, res).gotoFrameAndLabel);
        runner.runAsync("Play, stop, loop", new RuntimePlaybackTest(runner, res).playStopLoop);
        runner.runAsync("Stop, play", new RuntimePlaybackTest(runner, res).stopPlay);
        runner.runAsync("Play when added", new RuntimePlaybackTest(runner, res).playWhenAdded);
        runner.runAsync("Play once", new RuntimePlaybackTest(runner, res).playOnce);
        runner.runAsync("Pause while removed", new RuntimePlaybackTest(runner, res).pauseWhileRemoved);
    }

    public function RuntimePlaybackTest (runner :TestRunner, res :StarlingResources) {
        _runner = runner;
        _res = res;
    }

    protected function setup (finisher :VisibleFuture) :void {
        _finisher = finisher;
        _movie = _res.createMovie("nesteddance");
        assert(_movie.frame == 0, "Frame starts at 0");
        assert(_movie.isPlaying, "Movie starts out playing");
        _runner.addChild(_movie);
        _movie.labelPassed.add(_labelsPassed.push);
    }

    public function gotoFrameAndLabel () :void {
        _movie = _res.createMovie("nesteddance");
        _movie.labelPassed.add(_labelsPassed.push);
        _movie.goto("timepassed");
        assert(_movie.frame == 9);
        passed("timepassed");
        assert(_labelsPassed.length == 1);
        _movie.goto("timepassed");
        assert(_labelsPassed.length == 2);
        assert(_movie.isPlaying, "Playing changed in goto");

        _movie.stop();
        _movie.goto(_movie.frame + 1);
        assert(_movie.frame == 10);
        assert(!_movie.isPlaying, "Stopped changed in goto");

        assertThrows(F.callback(_movie.goto, _movie.frames), "Went past frames");
        assertThrows(F.callback(_movie.goto, "nonexistent label"), "Went to nonexistent label");
    }

    public function playWhenAdded (finisher :VisibleFuture) :void {
        setup(finisher);
        delayForAtLeastOneFrame(checkAdvanced);
    }

    public function checkAdvanced () :void {
        assert(_movie.frame > 0, "Frame advances with time");
        delayForOnePlaythrough(checkAllLabelsFired);
    }

    public function checkAllLabelsFired () :void {
        _runner.removeChild(_movie);
        passedAllLabels();
        _finisher.succeed();
    }

    public function playOnce (finisher :VisibleFuture) :void {
        setup(finisher);
        _movie.goto(0).play();
        delayForOnePlaythrough(checkPlayOnce);
    }

    public function checkPlayOnce () :void {
        passedAllLabels();
        assert(_labelsPassed.length == 4, "Only pass the labels once");
        assert(_movie.frame == _movie.frames - 1, "Play once stops at last frame");
        _runner.removeChild(_movie);
        _finisher.succeed();
    }

    public function pauseWhileRemoved (finisher :VisibleFuture) :void {
        setup(finisher);
        delayForAtLeastOneFrame(checkAdvancedToRemove);
    }

    public function checkAdvancedToRemove () :void {
       assert(_movie.frame > 0, "Playing initially");
       assert(_labelsPassed.length == 0, "Passed labels initially?");
       _runner.removeChild(_movie);
       delayForOnePlaythrough(checkNotAdvancedWhileRemoved);
    }

    public function checkNotAdvancedWhileRemoved () :void {
        assert(_labelsPassed.length == 0, "Labels passed while removed?");
        _runner.addChild(_movie);
        delayForOnePlaythrough(checkAllLabelsFired);
    }

    public function stopPlay (finisher :VisibleFuture) :void {
        setup(finisher);
        _movie.stop();
        delayForAtLeastOneFrame(checkNotAdvancedWhileStopped);
    }

    public function checkNotAdvancedWhileStopped () :void {
        assert(_movie.frame == 0, "Frame advanced passed while stopped?");
        _movie.goto(Movie.FIRST_FRAME).playTo("timepassed");
        delayForOnePlaythrough(checkPlayedToTimePassed);
    }

    public function checkPlayedToTimePassed () :void {
        passed(Movie.FIRST_FRAME);
        passed("timepassed");
        assert(_labelsPassed.length == 2, "Should stop at timepassed: " + _labelsPassed);
        _runner.removeChild(_movie);
        _finisher.succeed();
    }

    public function playStopLoop (finisher :VisibleFuture) :void {
        setup(finisher);
        _movie.goto(10).play().stop().loop();
        assert(_movie.frame == 10, "Play stop or loop changed the frame");
        delayFor(2.6, checkDoublePass);
    }

    public function checkDoublePass () :void {
        passedAllLabels();
        assert(_labelsPassed.length >= 8);
        _runner.removeChild(_movie);
        _finisher.succeed();
    }

    public function passedAllLabels () :void {
        passed("timepassed");
        passed("moretimepassed");
        passed(Movie.LAST_FRAME);
        passed(Movie.FIRST_FRAME);
    }

    protected function passed (label :String) :void {
        assert(_labelsPassed.indexOf(label) != -1, "Should've passed " + label);
    }

    protected function delayForOnePlaythrough (then :Function) :void { delayFor(1.3, then); }

    protected function delayForAtLeastOneFrame (then :Function) :void { delayFor(.1, then); }

    protected function delayFor (seconds :Number, then :Function) :void {
        const t :Timer = new Timer(1000 * seconds);
        t.addEventListener(TimerEvent.TIMER, function (..._) :void { postDelay(t, then); });
        t.start();
    }

    protected function postDelay (t :Timer, then :Function) :void {
        t.stop();
        _finisher.monitor(then);
    }

    protected var _finisher :VisibleFuture;
    protected var _movie :Movie;
    protected var _runner :TestRunner;
    protected var _res :StarlingResources;

    protected var _t :Timer = new Timer(1);
    protected const _labelsPassed :Vector.<String> = new <String>[];
}
}
