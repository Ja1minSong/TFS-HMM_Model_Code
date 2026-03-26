clc
clear
tic;

main_folder_path = 'Your main data folder path';
in_periodization_path = 'Your periodization table path';
start_subject_num = 13;
end_subject_num = 19;
[new_path]=test1(main_folder_path, in_periodization_path, start_subject_num, end_subject_num);