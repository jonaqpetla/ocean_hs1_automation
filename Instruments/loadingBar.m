classdef loadingBar < handle
    % make input for constructor to attach to panel/fig and make sizes
    % proportional to that

    properties(Access = private)
        numLevs
    end

    properties(Access = private)
        progressLevel
        t_elap
        t_rem
        figUI
        pr_axes
        StartTime
        timer
    end

    methods
        %% Constructor
        % Takes the UI element and attaches the loading bar to it
        function app = loadingBar(figUI, numLevs, timer)
            arguments
                figUI               % UI element to attach the loading bar to
                numLevs = 1;        % Number of levels of the loading bar to track the progress of sub-processes
                timer = true;       % Whether to show the timer or not 
            end

            app.figUI = figUI;  
            app.numLevs = numLevs;
            app.timer = timer;

            mainGrid = uigridlayout(app.figUI, [app.numLevs+1 1]);
            if timer
                mainGrid.RowHeight = [repmat({'1x'},1,app.numLevs), '2x'];
            else
                mainGrid.RowHeight = [repmat({'1x'},1,app.numLevs)];
            end
            mainGrid.ColumnWidth = {'1x'};
            mainGrid.Padding = [5 5 5 5];
            mainGrid.RowSpacing = 5;
            mainGrid.ColumnSpacing = 5;

            for kk = 1:app.numLevs
                ax = uiaxes(mainGrid);
                ax.Layout.Row = kk;
                
                disableDefaultInteractivity(ax);
                ax.Toolbar.Visible = 'off';
                ax.XLim = [0,1];
                ax.YLim = [0,1];
                ax.Box = "on";
                progressValue = 0;
                x = [0 progressValue progressValue 0];
                y = [0 0 1 1];
                set(ax,'XTick',[], 'YTick', []);
                fill(ax,x,y,[0,1,0,1]);

                app.pr_axes(kk) = ax;
            end

            if timer
                labelGrid = uigridlayout(mainGrid, [2 2]);
                labelGrid.Layout.Row = app.numLevs + 1;
                labelGrid.ColumnWidth  = {'3x', '1x'};
                labelGrid.RowHeight = {'1x', '1x'};
                labelGrid.Padding = [5 5 0 0];
                labelGrid.ColumnSpacing = 5;
                labelGrid.RowSpacing = 5;

                lbl1 = uilabel(labelGrid);
                lbl1.Layout.Column = 1;
                lbl1.Layout.Row = 1;
                lbl1.Text = 'Total time elapsed: ';
                lbl1.FontSize = 12;
                % lbl1.FontWeight = 'bold';
                lbl1.HorizontalAlignment = 'right';

                app.t_elap = uilabel(labelGrid);
                app.t_elap.Layout.Column = 2;
                app.t_elap.Layout.Row = 1;
                app.t_elap.Text = '--:--:--';
                app.t_elap.FontSize = 12;
                app.t_elap.FontWeight = 'bold';
                app.t_elap.HorizontalAlignment = 'left';    

                lbl2 = uilabel(labelGrid);
                lbl2.Layout.Column = 1;
                lbl2.Layout.Row = 2;
                lbl2.Text = 'Estimated time remaining: ';
                lbl2.FontSize = 12;
                % lbl2.FontWeight = 'bold';
                lbl2.HorizontalAlignment = 'right';

                app.t_rem = uilabel(labelGrid);
                app.t_rem.Layout.Column = 2;
                app.t_rem.Layout.Row = 2;
                app.t_rem.Text = '--:--:--';
                app.t_rem.FontSize = 12;
                app.t_rem.FontWeight = 'bold';
                app.t_rem.HorizontalAlignment = 'left';

                app.StartTime = datetime('now');
            end
        end

        %% Update progress bar based on ratios in ratio_list
        function update(app, ratio_list)
            arguments
                app
                ratio_list
            end

            for kk = 1:min(app.numLevs, length(ratio_list))     % Loop over number of levels or items in ratio_list, whcihever has lesser length
                app.updateFigure(ratio_list(kk), kk);
            end

            if app.timer
                [elap_seconds, rem_seconds] = app.findTime(ratio_list(1));

                elap_str = duration(elap_seconds(4:end), 'Format', 'hh:mm:ss');
                rem_str = duration(rem_seconds(4:end), 'Format', 'hh:mm:ss');
                app.t_elap.Text = string(elap_str);
                app.t_rem.Text = string(rem_str);
            end
        end

        %% Clear the parent UI element
        function close(app)
            delete(app.figUI.Children);
        end
    end

    methods (Access=private)
        function updateFigure(app, ratio, level)
            progressValue = ratio;
            x = [0 progressValue progressValue 0];
            y = [0 0 1 1];
            fill(app.pr_axes(level),x,y,[0.9290 0.6940 0.1250]);
        end

        function [elap_seconds,rem_seconds] = findTime(app,ratio)
            elap_seconds = datevec(datetime('now')) - datevec(app.StartTime);
            rem_seconds = elap_seconds.*(1/ratio - 1);
        end
    end
end
